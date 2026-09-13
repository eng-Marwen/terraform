# ============================================================
# Ubuntu Base Image
# ============================================================
# This section downloads one Ubuntu cloud image that all VMs reuse.
# A shared base image avoids downloading the same operating system image
# once for every node in the Kubernetes cluster.

# One shared Ubuntu cloud image owned by this project.
# Each VM uses this image as its backing store.

resource "libvirt_volume" "ubuntu_base" {
  # Name of the shared Ubuntu disk inside the libvirt storage pool.
  name = "auto_k8s-ubuntu-26.04-base.qcow2"

  # Use libvirt's default storage pool for the image.
  pool = "default"

  # Create the volume from content downloaded from the configured URL.
  create = {
    content = {
      # Terraform downloads this cloud image when the volume is created.
      url = var.ubuntu_image_url
    }
  }
}


# ============================================================
# VM Disks
# ============================================================

# Creates one writable disk for each VM.
# Each disk uses the shared Ubuntu image as its backing store.

resource "libvirt_volume" "ubuntu_disk" {
  # Create one volume for every VM in the var.vms map.
  for_each = var.vms

  # Give the disk the same name as its VM and add the QCOW2 extension.
  name = "${each.key}.qcow2"

  # Store the VM disk in libvirt's default pool.
  pool = "default"

  # Convert GiB to bytes.
  # each.value.disk is the disk size configured for this VM.
  capacity = each.value.disk * 1024 * 1024 * 1024

  # Store the disk in QCOW2 format.
  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    # Read unchanged blocks from the shared Ubuntu base image.
    path = libvirt_volume.ubuntu_base.path

    # Tell libvirt that the backing image is also QCOW2.
    format = {
      type = "qcow2"
    }
  }
}


# ============================================================
# Cloud-Init Disks
# ============================================================

# Creates one cloud-init ISO per VM.
# Cloud-init uses these ISO files to configure each VM during first boot.
#
# user_data used to be a single static file shared by every VM.
# It's now rendered per-VM from a template so the control-plane
# gets the CA + `kubeadm init`, and workers get `kubeadm join`
# with the pre-computed discovery hash -- no manual steps needed
# after `terraform apply`.

locals {
  # Find the name of the single VM marked as the control plane.
  control_plane_key = [for k, v in var.vms : k if v.role == "control-plane"][0]

  # Look up the control-plane IP so workers know where to run kubeadm join.
  control_plane_ip  = var.vms[local.control_plane_key].ip

  # Render a different bootstrap shell script for every VM.
  bootstrap_scripts = {
    # name is the VM name and vm contains its role and network settings.
    for name, vm in var.vms : name => templatefile("${path.module}/cloud-init/bootstrap.sh.tftpl", {
      # Pass the VM role so the template chooses init or join behavior.
      role           = vm.role
      # Pass the VM name for its hostname and Kubernetes node name.
      hostname       = name
      # Pass this VM's address to kubeadm init on the control plane.
      node_ip        = vm.ip
      # Pass the control-plane address to workers.
      cp_ip          = local.control_plane_ip
      # Pass the token used by workers when joining the cluster.
      token          = var.kubeadm_token
      # Pass the CA public-key hash used to verify the control plane.
      ca_hash        = data.external.ca_hash.result.hash
      # Pass the pod network range to kubeadm init.
      pod_cidr       = var.pod_network_cidr
      # Pass the Calico release that installs the pod network plugin.
      calico_version = var.calico_version
    })
  }

  # Render complete cloud-init YAML for every VM.
  user_data = {
    # Render one user-data document per VM using the cloud-init template.
    for name, vm in var.vms : name => templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
      # Set the role used by the cloud-init template's conditionals.
      role               = vm.role
      # Set the hostname and cloud-init metadata values.
      hostname           = name
      # Install this public key for SSH access as the ubuntu user.
      ssh_authorized_key = var.ssh_authorized_key
      # Give the control plane its pre-generated Kubernetes CA certificate.
      ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
      # Give the control plane its matching CA private key.
      ca_key_pem         = tls_private_key.ca.private_key_pem
      # Embed the rendered bootstrap script in the cloud-init document.
      bootstrap_script   = local.bootstrap_scripts[name]
    })
  }
}

resource "libvirt_cloudinit_disk" "ubuntu" {
  # Create one cloud-init ISO for every VM.
  for_each = var.vms

  # Use a predictable ISO name based on the VM name.
  name = "${each.key}-cloudinit.iso"

  # Attach the VM-specific cloud-init YAML as user-data.
  user_data = local.user_data[each.key]

  # Set the VM identity and hostname presented to cloud-init.
  meta_data = yamlencode({
    # Give cloud-init a stable identity for this VM.
    instance-id    = each.key
    # Set the guest's local hostname to the Terraform map key.
    local-hostname = each.key
  })
}


# ============================================================
# Kubernetes Virtual Machines
# ============================================================

# Creates one libvirt VM for each entry in var.vms.
# The for_each key becomes the libvirt domain name.

resource "libvirt_domain" "ubuntu" {
  # Create one domain for every configured Kubernetes VM.
  for_each = var.vms

  # Set the libvirt domain name, such as control-plane or worker-1.
  name        = each.key
  # Use KVM virtualization for hardware-assisted guest execution.
  type        = "kvm"
  # Allocate the configured amount of memory in MiB.
  memory      = each.value.memory
  memory_unit = "MiB"
  # Allocate the configured number of virtual CPUs.
  vcpu        = each.value.vcpu
  # Expose the host CPU features to improve guest performance.
  cpu = {
    mode = "host-passthrough"
  }

  # Define the guest firmware, architecture, machine type, and boot order.
  os = {
    # Use a hardware-virtualized machine.
    type         = "hvm"
    # Create an x86-64 guest.
    type_arch    = "x86_64"
    # Use the Q35 chipset model.
    type_machine = "q35"
    # Boot from the primary hard disk.
    boot_devices = [{ dev = "hd" }]
  }

  # Define the disks, network interface, serial port, and console.
  devices = {
    disks = [
      {
        # Use QEMU to access the disk in QCOW2 format.
        driver = {
          name = "qemu"
          type = "qcow2"
        }

        source = {
          file = {
            # Attach this VM's writable disk.
            file = libvirt_volume.ubuntu_disk[each.key].path
          }
        }

        target = {
          # Expose the disk to Linux as virtio device vda.
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        # Attach the cloud-init ISO as a CD-ROM device.
        device = "cdrom"

        source = {
          file = {
            # Attach the cloud-init ISO made for this VM.
            file = libvirt_cloudinit_disk.ubuntu[each.key].path
          }
        }

        target = {
          # Expose the ISO as the second disk on a SATA bus.
          dev = "sdb"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        # Assign the MAC address configured for this VM.
        mac = {
          address = each.value.mac
        }

        # Use a high-performance virtio network adapter.
        model = {
          type = "virtio"
        }

        source = {
          network = {
            # Connect the VM to the private Kubernetes libvirt network.
            network = libvirt_network.k8s.name
          }
        }

        wait_for_ip = {
          # Wait up to five minutes for libvirt to report a DHCP lease.
          timeout = 300
          # Obtain the address from the libvirt DHCP lease.
          source  = "lease"
        }
      }
    ]

    # Create a pseudo-terminal for the guest serial output.
    serials = [
      {
        type = "pty"
      }
    ]

    # Provide a serial console useful for debugging boot problems.
    consoles = [
      {
        # Use a pseudo-terminal as the console backend.
        type        = "pty"
        # Identify the console as a serial console to the guest.
        target_type = "serial"
        # Give the console the standard first serial-port name.
        target_name = "serial0"
      }
    ]
  }
}

