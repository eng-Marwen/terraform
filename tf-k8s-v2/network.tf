# ============================================================
# Kubernetes Network
# ============================================================

# Private NAT network for this Kubernetes cluster.
#
# DHCP reservations are now generated from var.vms (mac + ip live
# there) instead of being typed out separately here — one less
# place to keep in sync when you add a node or spin up a second
# cluster.

resource "libvirt_network" "k8s" {
  name      = "auto_k8s"
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [
    {
      address = var.network_gateway
      prefix  = var.network_prefix

      dhcp = {
        hosts = [
          for name, vm in var.vms : {
            mac  = vm.mac
            ip   = vm.ip
            name = name
          }
        ]
      }
    }
  ]
}
