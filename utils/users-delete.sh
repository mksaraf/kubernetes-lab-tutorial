#!/bin/bash
#
# Copyright 2018 - Adriano Pezzuto
# https://github.com/kalise
#
# Usage: sudo ./users-delete.sh
#
PROJECT=wallet-200410
REGION=europe-west1
ZONE=europe-west1-c
CLUSTER=kube
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
echo "Get user/password credentials to work as cluster administrator"
gcloud container clusters get-credentials $CLUSTER
USERNAME=$(gcloud container clusters describe $CLUSTER | grep username | awk '{print $2}')
PASSWORD=$(gcloud container clusters describe $CLUSTER | grep password | awk '{print $2}')
kubectl config set-credentials $USERNAME --username=$USERNAME --password=$PASSWORD
kubectl config set-context $(kubectl config current-context) --namespace=default --user=$USERNAME
echo
echo "Delete cluster-wide RBAC authorizations for all authenticated users"
kubectl delete rolebinding pods-viewer-all --namespace=kube-system
kubectl delete role pods-viewer --namespace=kube-system
kubectl delete clusterrolebinding nodes-viewer-all volumes-viewer-all storage-classes-viewer-all
kubectl delete clusterrole nodes-viewer volumes-viewer storage-classes-viewer
for i in `seq -w 00 01`;
do
   USER=noverit$i;
   echo
   echo "====================================================================="
   echo "delete " $USER
   echo "====================================================================="
   
   echo "Delete service account"
   gcloud iam service-accounts delete $USER@$PROJECT.iam.gserviceaccount.com
   
   echo "Delete namespace"
   NAMESPACE=project${USER:7:2}
   kubectl delete ns $NAMESPACE
   
   echo "Remove the user and his own home dir"
   userdel -rf $USER
done
echo "Removing service account json files"
rm -rf .kube/user*.json
echo "Following service accounts remain"
gcloud iam service-accounts list
echo "Flush of users complete."
echo
