# Defines the base Ubuntu cloud image used as the starting point
# for creating the VM disk.
resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-26.04-base.qcow2" # Base image name
  pool = "default"                 # Libvirt storage pool

  create = {
    content = {
      url = var.ubuntu_image_url # Ubuntu cloud image URL
    }
  }
}

# Defines the VM's main virtual disk and uses the Ubuntu base image
# as its backing store, so the VM starts with a pre-installed OS and not from empty disk.
resource "libvirt_volume" "ubuntu_disk" {
  name     = "${var.vm_name}.qcow2" # VM disk name
  pool     = "default"              # Libvirt storage pool
  capacity = var.vm_disk_size       # Disk capacity

  target = {
    format = {
      type = "qcow2" # Virtual disk format
    }
  }

  backing_store = {
    path = libvirt_volume.ubuntu_base.path # Base image path

    format = {
      type = "qcow2" # Backing image format
    }
  }
}

# Defines the cloud-init ISO used to automatically configure
# the VM when Ubuntu starts for the first time.
resource "libvirt_cloudinit_disk" "ubuntu" {
  name = "${var.vm_name}-cloudinit.iso" # Cloud-init ISO name

  user_data = file("${path.module}/cloud-init.yml") # Cloud-init configuration

  meta_data = yamlencode({
    instance-id    = var.vm_name # VM instance ID
    local-hostname = var.vm_name # VM hostname
  })
}

# Defines the virtual machine itself, including its CPU, RAM,
# disks, boot configuration, and network interface.
resource "libvirt_domain" "ubuntu" {
  name        = var.vm_name   # VM name
  type        = "kvm"         # KVM virtualization
  memory      = var.vm_memory # VM RAM
  memory_unit = "MiB"         # RAM unit
  vcpu        = var.vm_vcpu   # Virtual CPU count

  os = {
    type         = "hvm"            # Fully virtualized machine
    type_arch    = "x86_64"         # Guest architecture
    type_machine = "q35"            # Virtual chipset
    boot_devices = [{ dev = "hd" }] # Boot from virtual hard disk
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
            file = libvirt_volume.ubuntu_disk.path # Main VM disk
          }
        }

        target = {
          dev = "vda"    # Disk device in the VM
          bus = "virtio" # Virtual disk interface
        }
      },
      {
        device = "cdrom" # Cloud-init as CD-ROM

        source = {
          file = {
            file = libvirt_cloudinit_disk.ubuntu.path # Cloud-init ISO
          }
        }

        target = {
          dev = "sdb"  # CD-ROM device
          bus = "sata" # Virtual SATA bus
        }
      }
    ]

    interfaces = [
      {
        model = {
          type = "virtio" # Virtual network adapter
        }

        source = {
          network = {
            network = "default" # Libvirt default network
          }
        }

        wait_for_ip = {
          timeout = 300     # Maximum wait time
          source  = "lease" # Get IP from DHCP lease
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

# 1. ubuntu_base
#    ↓
#    Provides the Ubuntu starting image

# 2. ubuntu_disk
#    ↓
#    Creates the VM's writable disk from that base image

# 3. cloudinit_disk
#    ↓
#    Provides automatic VM configuration

# 4. libvirt_domain
#    ↓
#    Creates the actual VM and attaches everything