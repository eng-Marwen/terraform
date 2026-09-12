# ============================================================
# Kubernetes VM Configuration
# ============================================================

variable "vms" {
  description = "Kubernetes virtual machines"

  type = map(object({
    role   = string
    memory = number
    vcpu   = number
    disk   = number
    mac    = string
  }))

  default = {
    "k8s-control-plane" = {
      role   = "control-plane"
      memory = 4096 # MiB = 4 GiB
      vcpu   = 2
      disk   = 20 # GiB
      mac    = "52:54:00:10:00:01"
    }

    "k8s-worker-01" = {
      role   = "worker"
      memory = 4096
      vcpu   = 2
      disk   = 20
      mac    = "52:54:00:10:00:02"
    }

    "k8s-worker-02" = {
      role   = "worker"
      memory = 4096
      vcpu   = 2
      disk   = 20
      mac    = "52:54:00:10:00:03"
    }
  }
}


# ============================================================
# Ubuntu Cloud Image
# ============================================================

variable "ubuntu_image_url" {
  description = "Ubuntu Server cloud image"

  type = string

  default = "https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img"
}


