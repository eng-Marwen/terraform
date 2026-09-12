# ============================================================
# Kubernetes Network
# ============================================================

# Private NAT network for this Kubernetes cluster.

resource "libvirt_network" "k8s" {
  name      = "k8s-network"
  autostart = true

  forward = {
    mode = "nat"
  }

  ips = [
    {
      address = "192.168.50.1"
      prefix  = 24

      dhcp = {
        hosts = [
          {
            mac  = "52:54:00:10:00:01"
            ip   = "192.168.50.100"
            name = "k8s-control-plane"
          },
          {
            mac  = "52:54:00:10:00:02"
            ip   = "192.168.50.101"
            name = "k8s-worker-01"
          },
          {
            mac  = "52:54:00:10:00:03"
            ip   = "192.168.50.102"
            name = "k8s-worker-02"
          }
        ]
      }
    }
  ]
}

