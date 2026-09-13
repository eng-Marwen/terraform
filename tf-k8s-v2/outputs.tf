output "control_plane_ip" {
  description = "IP address of the control-plane node"
  value       = local.control_plane_ip
}

output "node_ips" {
  description = "hostname => static IP for every VM"
  value       = { for name, vm in var.vms : name => vm.ip }
}

output "fetch_kubeconfig_command" {
  description = "Run this from your host once the control-plane has finished bootstrapping"
  value       = "scp ubuntu@${local.control_plane_ip}:/home/ubuntu/.kube/config ~/.kube/config && export KUBECONFIG=~/.kube/config"
}

output "bootstrap_log_hint" {
  description = "Where to check if a node doesn't come up as expected"
  value       = "ssh in and run: tail -f /var/log/k8s-bootstrap.log  (control-plane also has /var/log/k8s-label-workers.log)"
}
