# Kubernetes on KVM/libvirt

This project provisions a small Kubernetes cluster on a local Linux host using Terraform, QEMU/KVM, libvirt, Ubuntu cloud-init, and kubeadm.

The default cluster contains:

| Node | Role | Address | Resources |
| --- | --- | --- | --- |
| `control-plane` | Kubernetes control plane | `192.168.70.100` | 4 GiB RAM, 2 vCPU, 20 GiB disk |
| `worker-1` | Kubernetes worker | `192.168.70.101` | 4 GiB RAM, 2 vCPU, 20 GiB disk |
| `worker-2` | Kubernetes worker | `192.168.70.102` | 4 GiB RAM, 2 vCPU, 20 GiB disk |

The VMs are connected to the private NAT libvirt network `auto_k8s` (`192.168.70.0/24`).

## How it works

Terraform creates:

- An Ubuntu 26.04 cloud image and one writable QCOW2 disk per VM.
- The `auto_k8s` NAT network with DHCP reservations from `variables.tf`.
- One cloud-init ISO per VM.
- A Kubernetes CA before the VMs boot, allowing worker discovery hashes to be generated ahead of time.
- A control plane initialized with `kubeadm init` and workers joined with `kubeadm join`.
- Calico for the pod network.

Cloud-init performs the node preparation and Kubernetes bootstrap automatically. Bootstrap output is written to `/var/log/k8s-bootstrap.log` on every node.

## Prerequisites

Run these commands on a Linux host with hardware virtualization enabled:

- QEMU/KVM and libvirt
- A running system libvirt daemon and the `default` storage pool
- Terraform
- `virsh`
- OpenSSH client (`ssh` and `scp`)
- `kubectl`
- `bash`, `jq`, and `openssl`

The libvirt provider connects to `qemu:///system`, so the user running Terraform must have permission to access system libvirt. The default Ubuntu cloud image is downloaded automatically from `ubuntu-cloud-images.ubuntu.com` on the first apply.

## Configure

The defaults are defined in [`variables.tf`](variables.tf). To override them, create a local `terraform.tfvars` file or pass `-var` options.

At minimum, set `ssh_authorized_key` to the public key that should be installed for the `ubuntu` user:

```hcl
ssh_authorized_key = "ssh-ed25519 AAAA... user@host"
```

If changing node addresses, update the `vms` map and keep the control-plane address consistent with any host-side access commands. `pod_network_cidr` must match the Calico configuration used by the selected manifest.

## Deploy the cluster

From this directory:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```
then to run the cluster:
```bash
chmod +x ./run_cluster.sh
./run_cluster.sh
```

## Stop and destroy

Gracefully stop the VMs without deleting Terraform resources:

```bash
./stop_cluster.sh
```

## Troubleshooting

Inspect VM state and leases:

```bash
virsh list --all
virsh net-dhcp-leases auto_k8s
```
## Files

- [`main.tf`](main.tf): VM disks, cloud-init disks, and libvirt domains.
- [`network.tf`](network.tf): private NAT network and DHCP reservations.
- [`pki.tf`](pki.tf): Kubernetes CA and worker discovery hash.
- [`cloud-init/bootstrap.sh.tftpl`](cloud-init/bootstrap.sh.tftpl): node preparation and kubeadm commands.
- [`cloud-init/user-data.yaml.tftpl`](cloud-init/user-data.yaml.tftpl): cloud-init users, SSH, and bootstrap setup.
- [`variables.tf`](variables.tf): cluster, network, SSH, and Kubernetes settings.
- [`outputs.tf`](outputs.tf): node addresses and kubeconfig guidance.
- [`stop_cluster.sh`](stop_cluster.sh): graceful VM shutdown helper.