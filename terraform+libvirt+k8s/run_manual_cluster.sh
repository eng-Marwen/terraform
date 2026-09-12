#!/bin/bash


echo "Starting k8s-control-plane..."
virsh start k8s-control-plane
echo "k8s-control-plane started successfully."

echo "Starting k8s-worker-01..."
virsh start k8s-worker-01
echo "k8s-worker-01 started successfully."

echo "Starting k8s-worker-02..."
virsh start k8s-worker-02
echo "k8s-worker-02 started successfully."



mkdir -p ~/.kube
scp ubuntu@192.168.50.100:/home/ubuntu/.kube/config ~/.kube/config

#chmod +x ./fille.sh
#./file.sh