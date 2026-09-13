# Kubernetes Cluster Setup with kubeadm (1 Control Plane + 2 Workers)
kubeadm -> bootsrapping (eggs and chicken problem)

## 0. VM Layout

| Node | IP |
|---|---|
| k8s-control-plane | 192.168.50.100 |
| k8s-worker-01 | 192.168.50.101 |
| k8s-worker-02 | 192.168.50.102 |

Start the VMs and confirm they can ping each other on the same subnet:

```bash
virsh start k8s-control-plane
virsh start k8s-worker-01
virsh start k8s-worker-02
```

---

## 1. Prepare ALL 3 VMs

Run everything in this section on the control plane **and** both workers.

### a. Disable swap

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

Swap is disk space used as RAM overflow — Kubernetes requires it to be off so the scheduler's memory accounting stays accurate.

**Command breakdown — `sed -i '/ swap / s/^/#/' /etc/fstab`:**
This comments out the swap line in `/etc/fstab` so swap stays disabled after reboot, without needing to open a text editor.

### b. Load kernel modules

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

- `modprobe` — loads/removes kernel modules.
- `overlay` — a read-write layer on top of a read-only base, letting containers run and save changes without touching the original image.
- `br_netfilter` — routes container network traffic through the host firewall, so Kubernetes/Docker networks can communicate correctly.

### c. Configure sysctl for networking

```bash
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sudo sysctl --system
```

- `net.bridge.bridge-nf-call-iptables=1` — forces IPv4 bridge traffic through iptables so Kubernetes can route pod traffic safely.
- `net.bridge.bridge-nf-call-ip6tables=1` — same, for IPv6.
- `net.ipv4.ip_forward=1` — enables IP forwarding so the machine can route traffic between containers/nodes.
- `sudo sysctl --system` — applies all sysctl config files immediately, no reboot needed.

### d. Install containerd

```bash
sudo apt update
sudo apt install -y containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

`containerd config default` generates a complete, working default `config.toml` instead of writing one from scratch; `tee` saves it straight into place. Enabling `SystemdCgroup` aligns containerd's cgroup driver with kubelet's.

### e. Install Kubernetes packages

```bash
sudo apt update
sudo apt install -y kubeadm kubelet kubectl
```

| Tool | Role |
|---|---|
| `kubeadm` | Bootstraps, joins, and tears down the cluster |
| `kubelet` | Agent on every node that keeps containers running and healthy |
| `kubectl` | CLI used to talk to and manage the cluster |

---

## 2. Initialize the Control Plane

### a. Run kubeadm init

```bash
sudo kubeadm init --apiserver-advertise-address=192.168.50.100
```

This sets up the API server, etcd database, and core scheduling components. `--apiserver-advertise-address` pins the API server to a known IP so workers know exactly where to connect.

It will print a join command — **save it**:

```bash
kubeadm join 192.168.50.100:6443 \
    --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

### b. Configure kubectl access

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- `mkdir -p $HOME/.kube` — creates the hidden config directory `kubectl` looks for by default (`-p` means "don't error if it already exists").
- `cp -i /etc/kubernetes/admin.conf $HOME/.kube/config` — copies the cluster's admin credentials/certificates into place.
- `chown $(id -u):$(id -g) …` — hands ownership to your user so you don't need `sudo` for every `kubectl` command.

Test:

```bash
kubectl get nodes
```

Expect `k8s-control-plane   NotReady` at this point — that's normal, no CNI is installed yet.

### c. Install a CNI (Container Network Interface)

The CNI is the virtual router/switch for the cluster. Without it, pods can be scheduled but can't get IPs or talk to anything.

It handles three things:

1. **Pod-to-Pod (same node)** — each pod gets a private IP; the CNI wires them together locally via virtual interfaces (veth pairs) in the kernel.
2. **Pod-to-Node** — bridges the pod network with the host's network so the host can monitor, log, and route traffic to containers.
3. **Pod-to-Pod (across nodes)** — uses tunneling (e.g. VXLAN, Geneve) to encapsulate pod traffic inside normal host packets, ship it across the physical network, and unwrap it on the destination node — so pods appear to be on the same local network regardless of physical placement.

Pick **one**:

- Calico
- Cilium
- Flannel

Install it, then check:

```bash
kubectl get pods -A
kubectl get nodes
```

The control plane should flip to `Ready`.

---

## 3. Join the Worker Nodes

### Worker 01

SSH into `k8s-worker-01` and run the saved join command:

```bash
sudo kubeadm join 192.168.50.100:6443 \
    --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

### Worker 02

SSH into `k8s-worker-02` and run the same command:

```bash
sudo kubeadm join 192.168.50.100:6443 \
    --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

### What `kubeadm join` actually does

1. **Discovery (secure handshake)** — the worker fetches the cluster's root CA certificate from the control plane, hashes it, and checks it against `--discovery-token-ca-cert-hash` to confirm it's talking to the real master.
2. **Authentication** — the worker presents `--token`; the master validates it against the invitation token generated at `kubeadm init`.
3. **Certificate generation** — master and worker mint unique TLS certificates so all future communication is encrypted.
4. **Kubelet activation** — kubeadm configures and starts `kubelet`, which reports the node's available CPU/RAM back to the control plane.
5. **CNI rollout** — the control plane pushes the network plugin's agent (e.g. a Calico pod) onto the new node, wiring it into the cluster network and flipping its status from `NotReady` to `Ready`.

---

## 4. Verify the Cluster

From the control plane:

```bash
kubectl get nodes
```

Expected result:

```
NAME                  STATUS   ROLES
k8s-control-plane     Ready    control-plane
k8s-worker-01         Ready    <none>
k8s-worker-02         Ready    <none>
```

