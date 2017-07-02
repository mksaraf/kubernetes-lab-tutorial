#!/bin/bash -xv
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Create context for kubectl
#
USER=$(whoami)
NAMESPACE=project${USER:4:2}
CLUSTER=kubernetes
SERVER=http://10.10.10.90:8080
kubectl config set-credentials $USER
kubectl config set-cluster $CLUSTER --server=$SERVER
kubectl config set-context $NAMESPACE/$CLUSTER/$USER --cluster=$CLUSTER --user=$USER
kubectl config set contexts.$NAMESPACE/$CLUSTER/$USER.namespace $NAMESPACE
kubectl config use-context $NAMESPACE/$CLUSTER/$USER
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE type=project
kubectl create quota besteffort --hard=pods=10
kubectl describe namespace $NAMESPACE
