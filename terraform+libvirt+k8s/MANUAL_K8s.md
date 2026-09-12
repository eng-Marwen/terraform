# Full Guide — Building a 3-Node Kubernetes Cluster on libvirt VMs

## Overview

```
Terraform + libvirt
        │
        ▼
3 Linux VMs (KVM)
        │
        ▼
Network connectivity verified
        │
        ▼
Node preparation (swap, kernel modules, sysctl, containerd)
        │
        ▼
Install kubeadm / kubelet / kubectl
        │
        ▼
kubeadm init (control plane)
        │
        ▼
Install Pod network (Calico)
        │
        ▼
kubeadm join (workers)
        │
        ▼
Working 3-node cluster ✓
```

**Final cluster topology**

| Role | Hostname | IP |
|---|---|---|
| Control plane | `k8s-control-plane` | 192.168.50.100 |
| Worker 1 | `k8s-worker-01` | 192.168.50.101 |
| Worker 2 | `k8s-worker-02` | 192.168.50.102 |

*(Note: these IPs were reassigned partway through the build — see "IP stability" in the troubleshooting section.)*

---

## Phase 0 — Infrastructure (Terraform + libvirt)

Three VMs were provisioned with Terraform against a libvirt/KVM provider: one shared base Ubuntu cloud image (`libvirt_volume.ubuntu_base`), a writable qcow2 disk per VM backed by that image, a cloud-init ISO per VM (setting hostname per node), and a `libvirt_domain` resource (`for_each` over a `vms` map) defining each VM's memory, vCPUs, disks, network interface (with a pinned MAC address so DHCP hands back a stable IP), and CPU mode.

Key detail worth calling out: the `cpu` block in the domain resource controls what instruction set the VM's virtual CPU exposes — this becomes critical later (see Calico CPU issue below).

Before touching Kubernetes at all, connectivity between the three VMs on `192.168.50.0/24` was verified with `ping` in both directions between all nodes, since every later phase (etcd, API server, `kubeadm join`, Calico) depends on nodes being able to reach each other.

---

## Phase 1 — Node preparation (run on **all 3 VMs**)

### 1. Disable swap

```bash
sudo swapoff -a
free -h   # confirm Swap: 0B
```

**Why:** Kubernetes needs predictable control over memory for the kubelet's eviction decisions. If the OS can silently push workload memory to disk (swap), that predictability breaks.

**Important:** `swapoff -a` only affects the *running* system. It is **not persistent** — if `/etc/fstab` still has a swap entry, swap can come back after a reboot and prevent kubelet from starting cleanly. Fix this permanently:

```bash
sudo sed -i '/swap/s/^/#/' /etc/fstab
swapon --show   # should print nothing
```

### 2. Load kernel modules

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
lsmod | grep overlay
lsmod | grep br_netfilter
```

**Why:**
- `overlay` — lets containerd build a container's filesystem from stacked image layers (OverlayFS).
- `br_netfilter` — lets packets crossing a Linux bridge get processed by netfilter, which Kubernetes networking/firewalling depends on.

To persist these across reboots:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

### 3. Configure sysctl (networking)

```bash
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
sysctl net.ipv4.ip_forward   # confirm = 1
```

**Why:**
- `ip_forward = 1` lets the node act as a router, forwarding traffic between the Pod network, the node, and other Pods/nodes.
- The bridge-nf settings ensure bridged traffic (how Pod network bridges work) is correctly seen by iptables/netfilter.

This file is already persistent (`/etc/sysctl.d/` is read on every boot).

---

## Phase 2 — Install containerd (run on **all 3 VMs**)

```bash
sudo apt update
sudo apt install -y containerd
containerd --version
```

**Why:** Kubernetes doesn't run containers itself — the kubelet talks to a container runtime through the CRI (Container Runtime Interface). `containerd` is that runtime, using `runc` underneath to actually create containers:

```
kubelet → CRI → containerd → runc
```

### Generate and edit config

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo nano /etc/containerd/config.toml
```

Find `SystemdCgroup = false` → change to `SystemdCgroup = true`.

**Why:** The cgroup driver used by containerd must match the one used by the kubelet (systemd, on modern distros). A mismatch causes instability.

### Restart, enable, and verify

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd     # ensures it starts on every boot
sudo systemctl status containerd     # expect: Active (running)
sudo containerd config dump | grep SystemdCgroup   # expect: true
```

---

## Phase 3 — Install kubeadm, kubelet, kubectl (run on **all 3 VMs**)

### 1. Prerequisites

```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg
```

### 2. Add the Kubernetes repo signing key

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

**Why:** APT needs to verify packages really came from the official Kubernetes repo. `gpg --dearmor` converts the downloaded key into the binary format APT expects.

### 3. Add the repo and install

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl

kubeadm version
kubelet --version
kubectl version --client
```

### 4. Pin the versions

```bash
sudo apt-mark hold kubelet kubeadm kubectl
apt-mark showhold
```

**Why:** Prevents `apt upgrade` from silently bumping Kubernetes components out from under a running cluster.

`kubeadm init`/`kubeadm join` (next phases) automatically run `systemctl enable kubelet`, so no manual step is needed for that.

---

## Phase 4 — Initialize the control plane (run **only on the control-plane VM**)

```bash
sudo kubeadm init
```

**What this does:** stands up the control-plane components (API server, scheduler, controller-manager, etcd), starts `kubelet`/`kube-proxy` on that node, generates cluster certs/config, and prints a `kubeadm join ...` command for the workers to use later. Do **not** run this on the workers.

### Configure kubectl for your user

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes
```

**Why:** `kubeadm init` writes cluster credentials to `/etc/kubernetes/admin.conf`. Copying it to `~/.kube/config` lets `kubectl` running as your normal user authenticate to the cluster. (Note: this file only exists on the control-plane — running `kubectl` on a worker without this setup gives a `localhost:8080 connection refused` error, which is expected, not a bug.)

Expected output at this stage: the node shows `NotReady` — this is expected, since there's no Pod network yet.

---

## Phase 5 — Install the Pod network (Calico) — **control plane only**

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/calico.yaml
```

**Why:** Kubernetes has two separate networks — the node/VM network (already working) and the Pod network, which needs a CNI plugin. Calico implements it. This command creates a `DaemonSet` (`calico-node`, one Pod per node — including workers, automatically, once they join), a `Deployment` (`calico-kube-controllers`), and supporting RBAC/CRDs/config. Only needs to be applied once, from the control plane.

### Watch it come up

```bash
kubectl get pods -n kube-system
watch kubectl get pods -n kube-system   # Ctrl+C to exit
```

### Confirm node is Ready

```bash
kubectl get nodes
```

Once Calico's agent is running, the kubelet sees a functioning CNI and flips the node to `Ready`.

---

## Phase 6 — Join the workers

Get the join command (either the one printed at the end of `kubeadm init`, or regenerate a fresh one — tokens expire after 24h by default):

```bash
kubeadm token create --print-join-command
```

Run the printed command on **each worker, one at a time**:

```bash
sudo kubeadm join <control-plane-ip>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

Then from the control plane:

```bash
kubectl get nodes
```

The new worker shows `NotReady` briefly, then flips to `Ready` once Calico's DaemonSet schedules an agent Pod onto it. Repeat for the second worker.

### Why nodes show ROLES as `<none>`

`kubeadm init` automatically labels the control-plane node with `node-role.kubernetes.io/control-plane`. `kubeadm join` does **not** apply any role label to workers — this is cosmetic only and doesn't affect scheduling or function. To label them explicitly:

```bash
kubectl label node k8s-worker-01 node-role.kubernetes.io/worker=
kubectl label node k8s-worker-02 node-role.kubernetes.io/worker=
```

---

## Troubleshooting encountered during this build

### Issue 1 — `Init:ErrImagePull` on calico-node (TLS handshake timeout)

**Symptom:** `calico-node` stuck in `Init:ErrImagePull`, `kubectl describe pod` showed a `TLS handshake timeout` pulling from `quay.io`.

**Cause:** Transient slow/high-latency path from the VM's NAT'd network out to quay.io's CDN.

**Fix:** Retried the pull manually:
```bash
sudo crictl pull quay.io/calico/cni:v3.32.2
```
It succeeded on retry — kubelet's built-in backoff/retry also would have resolved it eventually on its own.

### Issue 2 — `Init:CrashLoopBackOff` on calico-node (`upgrade-ipam`)

**Symptom:** After the image pull succeeded, `calico-node` crash-looped in its first init container.

**Diagnosis:**
```bash
kubectl logs -n kube-system <calico-node-pod> -c upgrade-ipam
```
Output:
```
This program can only be run on AMD64 processors with v2 microarchitecture support.
```

**Cause:** Calico v3.32's images require the `x86-64-v2` microarchitecture level (SSE4.1/4.2, POPCNT, etc). The VM's libvirt domain was configured with `cpu.mode = "custom"` / `model qemu64`, which masks those CPU features from the guest even though the physical host supports them.

**Fix:**
1. Confirm the host actually supports v2:
   ```bash
   lscpu | grep -i flags | grep -o 'sse4_2\|popcnt\|sse4_1\|ssse3'
   ```
2. Set `host-passthrough` in the Terraform `libvirt_domain` resource:
   ```hcl
   cpu = {
     mode = "host-passthrough"
   }
   ```
3. **Terraform updating the `.tf` file is not enough** — the live domain must actually be recreated. Force it:
   ```bash
   terraform apply -replace="libvirt_domain.ubuntu[\"k8s-control-plane\"]" \
                    -replace="libvirt_domain.ubuntu[\"k8s-worker-01\"]" \
                    -replace="libvirt_domain.ubuntu[\"k8s-worker-02\"]"
   ```
4. Verify the *running* domain (not just the Terraform state) actually changed:
   ```bash
   virsh dumpxml <vm-name> | grep -A2 "<cpu"
   # expect: <cpu mode='host-passthrough' check='none' migratable='on'/>
   ```
5. Verify inside each VM the flags are now visible:
   ```bash
   lscpu | grep -i flags | grep -o 'sse4_2\|popcnt\|sse4_1\|ssse3'
   ```
6. Delete the crash-looping pod so it's rescheduled fresh:
   ```bash
   kubectl delete pod -n kube-system <calico-node-pod>
   ```

**Lesson:** Disks/cloud-init are separate Terraform resources from the domain, so replacing the domain via `-replace` is safe — it destroys/recreates only the VM definition, not its data.

### Issue 3 — Transient `Init:Error` on a newly-joined worker's calico-node

**Symptom:** Right after `kubeadm join`, `calico-node` on the new worker briefly showed `Init:Error`, and its `upgrade-ipam` log showed a 30-second timeout trying to reach the API's ClusterIP (`10.96.0.1:443`) before falling back and completing successfully anyway.

**Diagnosis:** Checked each init container in order (`upgrade-ipam` → `install-cni` → `ebpf-bootstrap`) with `kubectl logs -n kube-system <pod> -c <container>`. `upgrade-ipam` and `install-cni` both completed successfully despite the earlier error/warning.

**Resolution:** Self-healed — kubelet automatically retries failed init containers, and the node reached `Ready` on its own within a few minutes without manual intervention.

**Note on false leads:** Running `kubectl get pods` *on a worker node* (instead of the control-plane) produced `connection refused to localhost:8080` — this is expected, since only the control-plane has `~/.kube/config` set up; it's not an error to chase.

### Issue 4 — Control-plane IP address changed mid-build

**Symptom:** The control-plane's IP changed from `.102` to `.100`, and the two workers were correspondingly reassigned to `.101`/`.102`.

**Why this matters:** Every worker's `kubeadm join` command embeds the control-plane's IP at join time, and it's baked into each node's kubelet config. If the control-plane's IP changes *after* nodes have already joined, those nodes lose contact with the API server until reconfigured.

**Fix applied:** Since this was caught *before* any workers joined, the fresh join command was simply regenerated against the new IP:
```bash
kubeadm token create --print-join-command
```

---

## Reboot / restart safety

Kubernetes cluster state lives on disk (etcd data, PKI certs, kubelet config) — not in memory — so a full shutdown/restart of all three VMs is expected to come back cleanly, provided:

1. **containerd and kubelet are enabled as systemd services** (already done — `containerd` explicitly via `systemctl enable`, `kubelet` automatically by `kubeadm init`/`join`).
2. **Swap stays disabled after reboot** — `swapoff -a` alone is not persistent; the `/etc/fstab` swap line must be commented out (see Phase 1, step 1) or kubelet may refuse to start cleanly on boot.
3. **Node IPs stay stable across reboots** — since MAC addresses are pinned per-VM in Terraform, libvirt's DHCP should hand back the same lease each time. Worth confirming after any reboot:
   ```bash
   virsh net-dhcp-leases <network-name>
   ```
   If the control-plane's IP ever drifts after nodes have already joined (unlike Issue 4 above, which was caught pre-join), every node's kubelet and kubeconfig would still point at the old IP and the cluster would break until reconfigured — this is the single biggest reboot-related risk in this setup.
4. **Boot order** isn't strictly required but is cleaner: bring the control-plane up first, wait for the API server to be reachable, then boot the workers — otherwise workers will just retry until it appears (self-healing, just slower if everything boots simultaneously).

**Safe way to test:** reboot one VM first before testing the whole cluster:

```bash
# on the libvirt host
virsh shutdown k8s-worker-02
# wait for it to power off, then
virsh start k8s-worker-02
```

```bash
# on the control-plane
kubectl get nodes -w
```

The rebooted node should briefly show `NotReady`, then flip back to `Ready` automatically as kubelet and `calico-node` come back up — no manual steps needed if swap and DHCP are stable.

---

## Final state

```
k8s-control-plane   192.168.50.100   Ready   control-plane
k8s-worker-01       192.168.50.101   Ready   worker
k8s-worker-02       192.168.50.102   Ready   worker
```

3/3 nodes joined, Calico Pod network running cluster-wide, containerd/kubelet enabled on boot. Cluster is functional and reboot-resilient, contingent on the swap/fstab and IP-stability checks above.

### Suggested next steps
- Deploy a small test workload (e.g. an nginx `Deployment` + `Service`) and confirm pod-to-pod networking works across nodes, not just on one.
- Install an Ingress controller if you plan to expose HTTP services.
- Decide on a `StorageClass` / persistent volume provisioner if workloads will need persistent storage.