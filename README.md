# Terraform Infrastructure Examples

This repository contains four Terraform projects that demonstrate progressively
larger infrastructure setups:

1. Docker containers and a small microservices stack.
2. A single Ubuntu virtual machine on KVM/libvirt.
3. A manually bootstrapped Kubernetes cluster on KVM/libvirt.
4. An automatically bootstrapped Kubernetes cluster on KVM/libvirt.

Each project is independent. Run Terraform commands from the project's own
directory, not from this repository root.

## Project Overview

| Project | Platform | Result | Main workflow |
| --- | --- | --- | --- |
| [`terraform+docker`](terraform+docker) | Docker Engine | Nginx/Apache demo or a multi-container microservices stack | Pull images, create containers and networks |
| [`terraform+libvirt`](terraform+libvirt) | QEMU/KVM + libvirt | One Ubuntu Server VM | Cloud-init configures the VM on first boot |
| [`terraform+libvirt+k8s`](terraform+libvirt+k8s) | QEMU/KVM + libvirt | Three-node Kubernetes cluster | Terraform creates VMs; kubeadm setup is manual |
| [`tf-k8s-v2`](tf-k8s-v2) | QEMU/KVM + libvirt | Three-node Kubernetes cluster | Cloud-init performs kubeadm bootstrap automatically |

## Common Prerequisites

- Linux host with internet access.
- Terraform.
- Git, Bash, and an SSH client.
- For Docker projects: Docker Engine and permission to use the Docker socket.
- For libvirt projects: QEMU/KVM, libvirt, `virsh`, and an active `default` storage pool.
- Hardware virtualization enabled in the host firmware for KVM projects.

The libvirt projects use the system connection `qemu:///system`. Check the
connection, networks, and storage pools with:

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
virsh -c qemu:///system pool-list --all
```


## General Terraform Workflow

For any project, change into its directory and run:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Use `terraform destroy` only when you want to remove the resources managed by
that project.

## 1. Docker Projects

The [`terraform+docker`](terraform+docker) directory contains two examples.

### Simple demo

[`terraform+docker/simple demo`](terraform+docker/simple%20demo) downloads the
latest Nginx and Apache images and creates:

- `nginx_container`, exposed on host port `8001`.
- `apache_container`, exposed on host port `8002`.

Run it with:

```bash
cd "terraform+docker/simple demo"
terraform init
terraform validate
terraform apply
```

Test the containers at `http://localhost:8001` and `http://localhost:8002`.

### Microservices stack

[`terraform+docker/microservices`](terraform+docker/microservices) creates a
Docker network named `microservices_network` and these containers:

- Frontend on port `8081`.
- Backend on port `4000`.
- AI microservice on port `8000`.
- Redis on port `6379`.
- RabbitMQ on port `5672`.
- Qdrant on port `6333`.

The frontend, backend, and AI images are pulled from Docker Hub. The project
also pulls RabbitMQ, Redis, and Qdrant images.

Create a local `terraform.tfvars` file for required credentials and service
settings. Do not commit it, because it contains sensitive values such as:

- Docker Hub credentials.
- Firebase, JWT, MongoDB, Mailjet, Cloudinary, Groq, and Jina credentials.

Example workflow:

```bash
cd terraform+docker/microservices
terraform init
terraform validate
terraform plan
terraform apply
```

Inspect the resulting containers with:

```bash
docker ps
docker network inspect microservices_network
```

Remove the Docker resources with:

```bash
terraform destroy
```

## 2. Single Ubuntu VM on libvirt

[`terraform+libvirt`](terraform+libvirt) creates one headless Ubuntu Server VM.
The default VM is named `ubuntu-server-01` and uses:

- 2 GiB RAM.
- 2 vCPUs.
- A 20 GiB QCOW2 disk.
- The libvirt `default` network.
- Cloud-init for the `ubuntu` user, SSH access, DHCP, and the QEMU guest agent.

Deploy it with:

```bash
cd terraform+libvirt
terraform init
terraform validate
terraform plan
terraform apply
```

Find the VM address and connect over SSH:

```bash
virsh -c qemu:///system net-dhcp-leases default
ssh ubuntu@<VM_IP>
```

The SSH public key is configured in `cloud-init.yml`. Replace the example key
with your own public key before deployment. The VM also provides a serial
console for troubleshooting:

```bash
virsh -c qemu:///system console ubuntu-server-01
```

## 3. Kubernetes with Manual Bootstrap

[`terraform+libvirt+k8s`](terraform+libvirt+k8s) creates three Ubuntu VMs on a
private libvirt network:

| Node | Address |
| --- | --- |
| `k8s-control-plane` | `192.168.50.100` |
| `k8s-worker-01` | `192.168.50.101` |
| `k8s-worker-02` | `192.168.50.102` |

Terraform creates the VMs, disks, network, and cloud-init configuration. The
Kubernetes installation and `kubeadm join` steps are documented in
[`MANUAL_K8s.md`](terraform+libvirt+k8s/MANUAL_K8s.md).

From the `infrastructure` directory, initialize and apply Terraform:

```bash
cd terraform+libvirt+k8s/infrastructure
terraform init
terraform validate
terraform apply
```

Then follow the manual Kubernetes steps. The helper script can start the VMs,
wait for SSH, copy the kubeconfig, and wait for the Kubernetes API:

```bash
cd ..
chmod +x run_manual_cluster.sh stop_manual_cluster.sh
./run_manual_cluster.sh
```

Stop the VMs without destroying them:

```bash
./stop_manual_cluster.sh
```

## 4. Kubernetes with Automated Bootstrap

[`tf-k8s-v2`](tf-k8s-v2) is the more automated Kubernetes implementation. It
creates the following default nodes on the `auto_k8s` NAT network:

| Node | Role | Address |
| --- | --- | --- |
| `control-plane` | Control plane | `192.168.70.100` |
| `worker-1` | Worker | `192.168.70.101` |
| `worker-2` | Worker | `192.168.70.102` |

Cloud-init automatically prepares each node, installs containerd and the
Kubernetes packages, runs `kubeadm init` on the control plane, joins workers,
and installs Calico. The project pre-generates the Kubernetes CA and worker
discovery hash in Terraform so no manual join command is required.

Deploy the infrastructure from the project directory:

```bash
cd tf-k8s-v2
terraform init
terraform validate
terraform plan
terraform apply
```

Run the clusetr:

```bash
cd ..
chmod +x run_cluster.sh stop_cluster.sh
./run_cluster.sh
```

Stop the VMs without destroying them:

```bash
./stop_manual_cluster.sh
```

Bootstrap logs are available on each node at
`/var/log/k8s-bootstrap.log`. The control plane also writes worker-labeling
messages to `/var/log/k8s-label-workers.log`.


## State and Secrets

Terraform state files can contain private keys, credentials, and resource
details. Do not commit `terraform.tfstate`, `terraform.tfstate.backup`, or
secret-filled `terraform.tfvars` files to a public repository. Use a secure
remote backend for shared or production state, and rotate credentials that may
already have been exposed.

## Cleanup

Run cleanup from the same project directory where the resources were created:

```bash
terraform destroy
```

For Kubernetes projects, stop the VMs first when possible. Docker resources can
be inspected independently with `docker ps`, while libvirt resources can be
inspected with `virsh list --all`.
