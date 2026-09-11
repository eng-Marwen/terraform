terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Terraform
#    ↓
# libvirt provider
#    ↓
# libvirt API
#    ↓
# QEMU/KVM