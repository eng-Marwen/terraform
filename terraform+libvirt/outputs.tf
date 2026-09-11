output "vm_name" {
  description = "Created VM name"
  value       = libvirt_domain.ubuntu.name
}

output "vm_id" {
  description = "Libvirt domain ID"
  value       = libvirt_domain.ubuntu.id
}