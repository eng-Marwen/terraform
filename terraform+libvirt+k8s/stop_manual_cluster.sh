#!/bin/bash

echo "Shutting down k8s-control-plane..."
virsh shutdown k8s-control-plane #take longer time

echo "Shutting down k8s-worker-01..."
virsh shutdown k8s-worker-01

echo "Shutting down k8s-worker-02..."
virsh shutdown k8s-worker-02


#chmod +x ./fille.sh
#./file.sh