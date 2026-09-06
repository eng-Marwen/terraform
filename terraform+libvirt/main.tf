# Ubuntu cloud image
resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-26.04-base.qcow2"
  pool = "default"

  create = {
    content = {
      url = var.ubuntu_image_url
    }
  }
}

# VM disk based on the Ubuntu cloud image
resource "libvirt_volume" "ubuntu_disk" {
  name     = "${var.vm_name}.qcow2"
  pool     = "default"
  capacity = var.vm_disk_size

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

# Cloud-init configuration
resource "libvirt_cloudinit_disk" "ubuntu" {
  name = "${var.vm_name}-cloudinit.iso"

  user_data = file("${path.module}/cloud-init.yml")

  meta_data = yamlencode({
    instance-id    = var.vm_name
    local-hostname = var.vm_name
  })
}

# Ubuntu VM
resource "libvirt_domain" "ubuntu" {
  name        = var.vm_name
  type        = "kvm"
  memory      = var.vm_memory
  memory_unit = "MiB"
  vcpu        = var.vm_vcpu

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        source = {
          pool = {
            pool = "default"
            volume = {
              volume = libvirt_volume.ubuntu_disk.name
            }
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
          pool = {
            pool = "default"
            volume = {
              volume = libvirt_cloudinit_disk.ubuntu.name
            }
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
        model = {
          type = "virtio"
        }

        source = {
          network = {
            network = "default"
          }
        }

        wait_for_ip = {
          timeout = 300
          source  = "lease"
        }
      }
    ]
  }
}