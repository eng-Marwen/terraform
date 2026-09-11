variable "vm_name" {
  description = "Name of the Ubuntu VM"
  type        = string
  default     = "ubuntu-server-01"
}

variable "vm_memory" {
  description = "VM memory in MiB"
  type        = number
  default     = 2048
}

variable "vm_vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "VM disk size in bytes"
  type        = number
  default     = 20 * 1024 * 1024 * 1024
}

variable "ubuntu_image_url" {
  description = "Ubuntu Server cloud image"
  type        = string
  default = "https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img"
}

# Ubuntu cloud image: provides a pre-installed OS that can be automatically
# customized with cloud-init, enabling Terraform to create and configure VMs
# without manual OS installation and configuration.