# ============================================================
# Ubuntu Base Image
# ============================================================

# One shared Ubuntu cloud image owned by this project.
# Each VM uses this image as its backing store.

resource "libvirt_volume" "ubuntu_base" {
  name = "k8s-ubuntu-26.04-base.qcow2"
  pool = "default"

  create = {
    content = {
      url = var.ubuntu_image_url
    }
  }
}


# ============================================================
# VM Disks
# ============================================================

# Creates one writable disk for each VM.

resource "libvirt_volume" "ubuntu_disk" {
  for_each = var.vms

  name = "${each.key}.qcow2"
  pool = "default"

  # Convert GiB to bytes.
  capacity = each.value.disk * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = libvirt_volume.ubuntu_base.path

    format = {
      type = "qcow2"
    }
  }
}


# ============================================================
# Cloud-Init Disks
# ============================================================

# Creates one cloud-init ISO per VM.
#
# The hostname is generated automatically from each.key.
# Example:
# k8s-control-plane
# k8s-worker-01
# k8s-worker-02

resource "libvirt_cloudinit_disk" "ubuntu" {
  for_each = var.vms

  name = "${each.key}-cloudinit.iso"

  user_data = file("${path.module}/cloud-init.yml")

  meta_data = yamlencode({
    instance-id    = each.key
    local-hostname = each.key
  })
}


# ============================================================
# Kubernetes Virtual Machines
# ============================================================

# Creates one libvirt VM for each entry in var.vms.

resource "libvirt_domain" "ubuntu" {
  for_each = var.vms

  name        = each.key
  type        = "kvm"
  memory      = each.value.memory
  memory_unit = "MiB"
  vcpu        = each.value.vcpu
  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        driver = {
          name = "qemu"
          type = "qcow2"
        }

        source = {
          file = {
            file = libvirt_volume.ubuntu_disk[each.key].path
          }
        }

        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"

        source = {
          file = {
            file = libvirt_cloudinit_disk.ubuntu[each.key].path
          }
        }

        target = {
          dev = "sdb"
          bus = "sata"
        }
      }
    ]

    interfaces = [
      {
        mac = {
          address = each.value.mac
        }

        model = {
          type = "virtio"
        }

        source = {
          network = {
            network = libvirt_network.k8s.name
          }
        }

        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]

    serials = [
      {
        type = "pty"
      }
    ]

    consoles = [
      {
        type        = "pty"
        target_type = "serial"
        target_name = "serial0"
      }
    ]
  }
}


# ============================================================
# Outputs
# ============================================================

# Displays the VM names and assigned IP addresses.

# output "vm_ips" {
#   description = "IP addresses of the Kubernetes VMs"

#   value = {
#     for name, vm in libvirt_domain.ubuntu :
#     name => vm.network_interface[0].addresses
#   }
# }
