#!/bin/bash
#
# Copyright 2018 - Adriano Pezzuto
# https://github.com/kalise
#
# Usage: sudo ./users-add.sh
# Make sure the private ssh key ~/.ssh/gcp.pem is present in granting user home dir
# Also ~/.ssh/config contains the "IdentityFile ~/.ssh/gcp.pem" string

echo
echo "========================================================"
echo "Starting setup ..."
echo "========================================================"
echo
GRANT_USER=adriano_pezzuto
echo "GRANT_USER is   " $GRANT_USER
PROJECT=wallet-200410
echo "PROJECT is      " $PROJECT
REGION=europe-west1
echo "REGION is       " $REGION
ZONE=europe-west1-c
echo "ZONE is         " $ZONE
CLUSTER=kube
echo "CLUSTER is      " $CLUSTER
echo
echo "Check the pre-requisites here:"
echo "1.kubectl, 2.docker, 3.jq" 
echo
echo "Set the primary service account"
PRIMARY_SA=$(gcloud auth list | grep '*' | awk '{print $2}')
echo
echo "Set the environment"
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
echo
echo "Get user/password credentials to work as cluster administrator"
gcloud container clusters get-credentials $CLUSTER
USERNAME=$(gcloud container clusters describe $CLUSTER | grep username | awk '{print $2}')
PASSWORD=$(gcloud container clusters describe $CLUSTER | grep password | awk '{print $2}')
kubectl config set-credentials $USERNAME --username=$USERNAME --password=$PASSWORD
kubectl config set-context $(kubectl config current-context) --namespace=default --user=$USERNAME
echo
echo "Configure cluster-wide RBAC authorizations for all authenticated users"
echo "- pods viewer in kube-system"
kubectl create role pods-viewer --verb=get --verb=list --verb=watch --resource=pods --namespace=kube-system
kubectl create rolebinding pods-viewer-all --role=pods-viewer --group=system:authenticated --namespace=kube-system
echo "- node viewer"
kubectl create clusterrole nodes-viewer --verb=get --verb=list --verb=watch --resource=nodes
kubectl create clusterrolebinding nodes-viewer-all --clusterrole=nodes-viewer --group=system:authenticated
echo "- volumes viewer"
kubectl create clusterrole volumes-viewer --verb=get --verb=list --verb=watch --resource=pv
kubectl create clusterrolebinding volumes-viewer-all --clusterrole=volumes-viewer --group=system:authenticated 
echo "- storage classes viewer"
kubectl create clusterrole storage-classes-viewer --verb=get --verb=list --verb=watch --resource=sc
kubectl create clusterrolebinding storage-classes-viewer-all --clusterrole=storage-classes-viewer --group=system:authenticated
echo
echo "Install the gcloud-token-renew script as system binary"
cp ./gcloud-token-renew /usr/bin
chmod ugo+x /usr/bin/gcloud-token-renew

for i in `seq -w 00 01`;
do
        USER=noverit$i;
        echo
        echo "====================================================================="
        echo "add" $USER
        echo "====================================================================="
        useradd $USER
        echo
        echo "set password"
        echo $USER:password | chpasswd
        echo "set sudo permissions"
        usermod -aG wheel $USER
        echo "set permissions to run docker commands"
        usermod -aG docker $USER
        echo "copy ssh key"
        mkdir /home/$USER/.ssh
        chmod 700 /home/$USER/.ssh
        chown $USER:$USER /home/$USER/.ssh
        cp /home/$GRANT_USER/.ssh/authorized_keys /home/$USER/.ssh/authorized_keys
        chmod 600 /home/$USER/.ssh/authorized_keys
        chown $USER:$USER /home/$USER/.ssh/authorized_keys
        echo "copy GCP key"
        cp /home/$GRANT_USER/.ssh/gcp.pem /home/$USER/.ssh/gcp.pem
        chmod 600 /home/$USER/.ssh/gcp.pem
        chown $USER:$USER /home/$USER/.ssh/gcp.pem
        echo "copy ssh config"
        cp /home/$GRANT_USER/.ssh/config /home/$USER/.ssh/config
        chmod 600 /home/$USER/.ssh/config
        chown $USER:$USER /home/$USER/.ssh/config
        echo
        echo "create service account"
        rm -rf /home/$GRANT_USER/.kube/$USER-sa.json
        gcloud iam service-accounts create $USER --display-name=$USER
        gcloud iam service-accounts keys create --iam-account $USER@$PROJECT.iam.gserviceaccount.com /home/$GRANT_USER/.kube/$USER-sa.json
        echo
        echo "activate the service account"
        gcloud auth activate-service-account $USER@$PROJECT.iam.gserviceaccount.com --key-file=/home/$GRANT_USER/.kube/$USER-sa.json
        echo
        echo "gets the service account token" 
        TOKEN=$(gcloud auth print-access-token --account=$USER@$PROJECT.iam.gserviceaccount.com)
        echo
        echo "Reset to the primary service account"
        gcloud config set account $PRIMARY_SA
        echo
        echo "copy service account file to the user's kubeconfig dir"
        mkdir /home/$USER/.kube
        cp /home/$GRANT_USER/.kube/$USER-sa.json /home/$USER/.kube/sa.json
        chown $USER:$USER -R /home/$USER/.kube
        echo
        echo "create the user's namespace and quotas"
        NAMESPACE=project${USER:7:2}
        kubectl create namespace $NAMESPACE
        kubectl create quota $NAMESPACE --hard=pods=16 --namespace=$NAMESPACE
        echo
        echo "create the user's RBAC authorizations"
        kubectl create rolebinding tenant-admin --clusterrole=admin --user=$USER@$PROJECT.iam.gserviceaccount.com --namespace=$NAMESPACE
        echo
        echo "let the user gets his own cluster credentials"
        su -c "gcloud config set compute/region $REGION" -s /bin/bash $USER
        su -c "gcloud config set compute/zone $ZONE" -s /bin/bash $USER
        su -c "gcloud config set container/cluster $CLUSTER" -s /bin/bash $USER
        su -c "gcloud container clusters get-credentials $CLUSTER" -s /bin/bash $USER
        echo
        echo "let the user configures his own kubeconfig file"
        su -c "kubectl config unset users.$(kubectl config current-context)" -s /bin/bash $USER
        su -c "kubectl config set-credentials $USER --token=$TOKEN" -s /bin/bash $USER
        su -c "kubectl config set-context $(kubectl config current-context) --namespace=$NAMESPACE --user=$USER" -s /bin/bash $USER
        echo
done
echo "Get user/password credentials to work as cluster administrator"
gcloud container clusters get-credentials $CLUSTER
USERNAME=$(gcloud container clusters describe $CLUSTER | grep username | awk '{print $2}')
PASSWORD=$(gcloud container clusters describe $CLUSTER | grep password | awk '{print $2}')
kubectl config set-credentials $USERNAME --username=$USERNAME --password=$PASSWORD
kubectl config set-context $(kubectl config current-context) --namespace=default --user=$USERNAME
echo
echo "Following service accounts are now active"
gcloud iam service-accounts list
echo
echo "Setup completed."
echo
