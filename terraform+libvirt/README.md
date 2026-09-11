# Ubuntu VM Provisioning with Terraform and libvirt

This project creates an Ubuntu Server virtual machine on a Linux host using
Terraform, KVM/QEMU, and libvirt. The VM is configured automatically with
cloud-init and is managed through the system libvirt connection.

The result is a headless server. No Ubuntu desktop or graphical environment is
installed. After the first boot, connect from the host with SSH.

## What This Project Creates

Terraform creates these resources:

1. **Ubuntu base volume**
	 - Downloads the Ubuntu Server cloud image.
	 - Stores it in the libvirt `default` storage pool.

2. **VM QCOW2 disk**
	 - Creates a writable QCOW2 disk using the Ubuntu image as its backing store.
	 - Uses copy-on-write, so the base image remains unchanged.

3. **Cloud-init disk**
	 - Creates an ISO containing `cloud-init.yml`.
	 - Configures the hostname, DHCP networking, user account, SSH key, and QEMU
		 guest agent during the VM's first boot.

4. **libvirt domain**
	 - Creates a KVM virtual machine with 2 GiB RAM, 2 vCPUs, a VirtIO disk, and
		 a VirtIO network interface.
	 - Connects the interface to libvirt's `default` network and DHCP service.
	 - Provides a serial console for headless troubleshooting.

## Project Files

| File | Purpose |
| --- | --- |
| `main.tf` | Defines the base image, VM disk, cloud-init ISO, and VM domain. |
| `providers.tf` | Configures the `dmacvicar/libvirt` Terraform provider and `qemu:///system`. |
| `variables.tf` | Defines VM name, memory, vCPU, disk size, and Ubuntu image URL. |
| `cloud-init.yml` | Configures the guest OS on first boot. |
| `outputs.tf` | Reserved for Terraform outputs. |

## Requirements

The commands below assume an Ubuntu or Debian-based Linux host.

### Hardware and virtualization

- A 64-bit Linux host.
- CPU virtualization enabled in firmware: Intel VT-x or AMD-V.
- At least 4 GiB of host RAM recommended.
- At least 10 GiB of free storage for the base image and VM disk.
- Internet access to download the Ubuntu cloud image and Terraform provider.

### Software

- KVM/QEMU
- libvirt and its system daemon
- libvirt default network and storage pool
- Terraform
- OpenSSH client
- `qemu-img` for optional disk diagnostics
- `virt-manager` is optional; it is not required to run or access the server

Example host installation:

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
	virtinst qemu-utils openssh-client
```

Add your user to the libvirt-related groups, then log out and back in:

```bash
sudo usermod -aG libvirt,kvm "$USER"
```

Check that the system libvirt connection works:

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
virsh -c qemu:///system pool-list --all
```

The `default` network should be active and the `default` storage pool should be
available. Start them if necessary:

```bash
sudo virsh net-start default
sudo virsh net-autostart default
sudo virsh pool-start default
sudo virsh pool-autostart default
```

## SSH Key Setup

The guest disables password-based SSH login and uses the public key listed in
`cloud-init.yml`. Make sure the matching private key exists on the host.

Generate an Ed25519 key if needed:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
```

Print the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Replace the value under `ssh_authorized_keys` in `cloud-init.yml` with your own
public key. Never put the private key in this repository.

## Deploy the VM

Run Terraform from this directory:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Review the plan and type `yes` when Terraform asks for confirmation. To apply
without the confirmation prompt:

```bash
terraform apply -auto-approve
```

Terraform downloads the Ubuntu image, creates the QCOW2 disk and cloud-init ISO,
and creates the `ubuntu-server-01` domain. The first boot can take several
minutes while cloud-init updates packages and installs `qemu-guest-agent`.

## Find the VM Address

The VM uses libvirt's private `default` network, normally backed by `virbr0`.
Find the DHCP lease with:

```bash
virsh -c qemu:///system net-dhcp-leases default
```

You can also inspect the VM interface:

```bash
virsh -c qemu:///system domiflist ubuntu-server-01
virsh -c qemu:///system domifaddr ubuntu-server-01 --source lease
```

Use the current lease for the VM's MAC address. Old leases can remain visible
after a VM is recreated, so do not automatically use the oldest address shown.

## Connect and Run Commands

Replace `<VM_IP>` with the current DHCP address:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<VM_IP>
```

Run one command remotely without opening an interactive shell:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<VM_IP> "hostname && id"
```

The `ubuntu` user has passwordless `sudo` because of the cloud-init setting:

```yaml
sudo: ALL=(ALL) NOPASSWD:ALL
```

## Headless Console Access

No GUI is required. The Terraform domain includes a serial PTY and console.
Use this when the VM has no reachable IP or SSH is not ready:

```bash
virsh -c qemu:///system console ubuntu-server-01
```

Press `Enter` if the console appears blank. Exit the console with `Ctrl+]`.

The console is an emergency/troubleshooting path. Normal administration should
use SSH.

## Changing cloud-init Configuration

Cloud-init is primarily a first-boot system. Editing `cloud-init.yml` does not
automatically re-run all settings inside an existing VM.

For a disposable development VM, recreate the cloud-init ISO and VM disk so the
configuration is applied from a clean boot:

```bash
terraform apply -auto-approve \
	-replace=libvirt_volume.ubuntu_disk \
	-replace=libvirt_cloudinit_disk.ubuntu \
	-replace=libvirt_domain.ubuntu
```

This destroys the VM's writable disk and all data stored in it. The Ubuntu base
image is not destroyed.

## Troubleshooting

Check the VM state and interface:

```bash
virsh -c qemu:///system domstate ubuntu-server-01
virsh -c qemu:///system domiflist ubuntu-server-01
```

Check the DHCP leases:

```bash
virsh -c qemu:///system net-dhcp-leases default
```

Check the VM disk and backing chain:

```bash
sudo qemu-img info /var/lib/libvirt/images/ubuntu-server-01.qcow2
```

The output should identify the VM disk as QCOW2 and show the Ubuntu base image
as its backing file. If the guest has an IP but SSH is unavailable, test port
22:

```bash
nc -vz <VM_IP> 22
```

If Terraform reports that the domain is running but there is no lease, verify
that the `default` network is active and inspect the serial console. A blank
graphical virt-manager window is expected because this project creates an
Ubuntu Server VM without a graphical device or desktop environment.

## Stop, Start, and Destroy

Stop and start the VM without Terraform:

```bash
virsh -c qemu:///system shutdown ubuntu-server-01
virsh -c qemu:///system start ubuntu-server-01
```

Destroy all Terraform-managed resources:

```bash
terraform destroy
```

This removes the VM domain, writable disk, and cloud-init disk. The downloaded
base image may remain in the libvirt storage pool.

## Default VM Values

| Setting | Default |
| --- | --- |
| VM name | `ubuntu-server-01` |
| Memory | `2048` MiB |
| vCPUs | `2` |
| Disk capacity | `20` GiB |
| Libvirt connection | `qemu:///system` |
| Network | `default` |
| Guest user | `ubuntu` |
| Guest OS | Ubuntu Server cloud image |
