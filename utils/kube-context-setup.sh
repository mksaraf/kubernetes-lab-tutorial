#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure the kube-context-setup.sh script is in the home dir of granting user
#
# Usage: sudo ./kube-context-setup.sh <SERVER_NAME>
#
SERVER=$1:8080 || http://localhost:8080
for i in `seq -w 01 12`;
do
     USER=user$i
     echo
     echo "set the kubernetes context for " $USER
     NAMESPACE=project${USER:4:2}
     echo "set the namespace " $NAMESPACE " for " $USER
     CLUSTER=kubernetes
     echo "set the cluster " $CLUSTER
     su -c "kubectl config set-credentials $USER" -s /bin/bash $USER
     su -c "kubectl config set-cluster $CLUSTER --server=$SERVER" -s /bin/bash $USER
     su -c "kubectl config set-context $NAMESPACE/$CLUSTER/$USER --cluster=$CLUSTER --user=$USER" -s /bin/bash $USER
     su -c "kubectl config set contexts.$NAMESPACE/$CLUSTER/$USER.namespace $NAMESPACE" -s /bin/bash $USER
     su -c "kubectl config use-context $NAMESPACE/$CLUSTER/$USER" -s /bin/bash $USER
     su -c "kubectl create namespace $NAMESPACE" -s /bin/bash $USER
     su -c "kubectl label namespace $NAMESPACE type=project" -s /bin/bash $USER
     su -c "kubectl create quota besteffort --hard=pods=10" -s /bin/bash $USER
     su -c "kubectl describe namespace $NAMESPACE" -s /bin/bash $USER
done
