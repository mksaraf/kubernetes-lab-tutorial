#!/bin/bash
NAME=kube
PODS_NETWORK_CIDR=10.38.0.0/16
SERVICES_NETWORK_CIDR=10.32.0.0/16
CLUSTER_VERSION=1.8.10-gke.0
NODE_VERSION=1.8.10-gke.0
DISK_SIZE=100
IMAGE_TYPE=UBUNTU
MACHINE_TYPE=n1-standard-1
NETWORK=kubernetes
SUBNETWORK=kubernetes
ZONE=europe-west1-c
NUM_NODES=3
MAX_NODES=5
MIN_NODES=1
gcloud container clusters create $NAME \
    --addons=KubernetesDashboard \
    --cluster-ipv4-cidr=$PODS_NETWORK_CIDR \
    --enable-ip-alias \
    --cluster-version=$CLUSTER_VERSION \
    --disk-size=$DISK_SIZE \
    --enable-cloud-monitoring \
    --image-type=$IMAGE_TYPE \
    --machine-type=$MACHINE_TYPE \
    --preemptible \
    --zone=$ZONE \
    --network=$NETWORK \
    --subnetwork=$SUBNETWORK \
    --node-locations=$ZONE \
    --node-version=$NODE_VERSION \
    --num-nodes=$NUM_NODES \
    --services-ipv4-cidr=$SERVICES_NETWORK_CIDR \
    --scopes=gke-default,storage-full,monitoring,sql,datastore \
    --username=admin \
    --enable-autoscaling --min-nodes=$MIN_NODES --max-nodes=$MAX_NODES \
    --no-enable-autorepair
echo "Cluster provisioned."
