#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure the gcloud cli utility is installed and
# initialized with proper credentials
#
# Usage: ./docker-setup.sh

NUM=5
REGION=europe-west1
ZONE=europe-west1-c
NETWORK=docker
IMAGE=projects/wallet-200410/global/images/users
ROLE=docker-machine
MACHINE_TYPE=n1-standard-1
TAG=docker
SCOPES=default,compute-ro,service-control,service-management,logging-write,monitoring-write,storage-ro
FIREWALL_RULES=tcp:22,tcp:443,tcp:80,tcp:8000-8099

# Create the network
echo "Creating the network" $NETWORK
gcloud compute networks create $NETWORK --subnet-mode=custom

# Create firewall rules
echo "Creating firewall rules"
gcloud compute firewall-rules create docker-allow-internal --network $NETWORK --allow tcp,udp,icmp  --source-ranges 10.10.0.0/16
gcloud compute firewall-rules create docker-allow-external --network $NETWORK --allow $FIREWALL_RULES

# Create the subnet
SUBNET=$REGION-docker-subnet
echo "Creating subnet" $SUBNET "in zone" $REGION
RANGE=10.10.0.0/16
gcloud compute networks subnets create $SUBNET \
  --network=$NETWORK \
  --range=$RANGE \
  --enable-private-ip-google-access \
  --region=$REGION

# Create the instances
VMCOUNT=10
for i in $(seq -w 0 $NUM);
do
    NAME=docker$(printf "%02.f" $i)
    ADDRESS=10.10.$VMCOUNT.2
    VMCOUNT=$(expr $VMCOUNT + 1)
    echo "Creating instance" $NAME "having IP" $ADDRESS
    gcloud compute instances create $NAME \
       --async \
       --boot-disk-auto-delete \
       --boot-disk-type=pd-standard \
       --can-ip-forward \
       --image=$IMAGE \
       --labels=role=$ROLE \
       --machine-type=$MACHINE_TYPE \
       --restart-on-failure \
       --network-interface=network=$NETWORK,subnet=$SUBNET,private-network-ip=$ADDRESS \
       --tags=$TAG \
       --zone=$ZONE \
       --scopes=$SCOPES
done
echo "Done"
