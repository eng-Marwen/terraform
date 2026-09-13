# ============================================================
# Kubernetes VM Configuration
# ============================================================

# NOTE: added `ip` here (it used to live only inside the
# libvirt_network dhcp block, duplicated by hand). Now network.tf
# derives its DHCP reservations from this map instead, so mac/ip
# only need to be entered once.

variable "vms" {
  description = "Kubernetes virtual machines"

  type = map(object({
    role   = string
    memory = number
    vcpu   = number
    disk   = number
    mac    = string
    ip     = string
  }))

  default = {
    "control-plane" = {
      role   = "control-plane"
      memory = 4096 # MiB = 4 GiB
      vcpu   = 2
      disk   = 20 # GiB
      mac    = "52:54:00:30:00:01"
      ip     = "192.168.70.100"
    }

    "worker-1" = {
      role   = "worker"
      memory = 4096
      vcpu   = 2
      disk   = 20
      mac    = "52:54:00:30:00:02"
      ip     = "192.168.70.101"
    }

    "worker-2" = {
      role   = "worker"
      memory = 4096
      vcpu   = 2
      disk   = 20
      mac    = "52:54:00:30:00:03"
      ip     = "192.168.70.102"
    }
  }

  validation {
    condition     = length([for k, v in var.vms : k if v.role == "control-plane"]) == 1
    error_message = "Exactly one VM in var.vms must have role = \"control-plane\"."
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


# ============================================================
# Network
# ============================================================

variable "network_gateway" {
  description = "Gateway/host address of the private NAT network"
  type        = string
  default     = "192.168.70.1"
}

variable "network_prefix" {
  description = "CIDR prefix length of the private NAT network"
  type        = number
  default     = 24
}


# ============================================================
# SSH access
# ============================================================

variable "ssh_authorized_key" {
  description = "Public key installed for the ubuntu user on every VM"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGFSPGsxRFiexvroYiu9Vw3y/00s00LlgMcH/rbF+Qa marwen@laptop"
}


# ============================================================
# Kubernetes bootstrap
# ============================================================

variable "pod_network_cidr" {
  description = "CIDR used for the Kubernetes Pod network (must match Calico's default IPPool unless you also edit the manifest)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "calico_version" {
  description = "Calico manifest version tag to install"
  type        = string
  default     = "v3.32.2"
}

variable "kubeadm_token" {
  description = "Static kubeadm bootstrap token shared by control-plane and workers. Format: 6 lowercase-alnum chars, a dot, 16 lowercase-alnum chars."
  type        = string
  default     = "abcdef.0123456789abcdef"

  validation {
    condition     = can(regex("^[a-z0-9]{6}\\.[a-z0-9]{16}$", var.kubeadm_token))
    error_message = "kubeadm_token must match kubeadm's token format: ^[a-z0-9]{6}\\.[a-z0-9]{16}$"
  }
}
