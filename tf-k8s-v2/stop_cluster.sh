#!/bin/bash

echo "Shutting down control-plane..."
virsh shutdown control-plane #take longer time

echo "Shutting down worker-1..."
virsh shutdown worker-1

echo "Shutting down worker-2..."
virsh shutdown worker-2


#chmod +x ./fille.sh
#./file.sh