#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure the kube-context-setup.sh script is in the home dir of granting user
# Make sure certificates: ca.pem, client.pem, client-key.pem are in the ~/.kube home dir of granting user
# Usage: sudo ./secure-kube-context-setup.sh <SERVER> <PORT>
#
SERVER=$1:$2
for i in `seq -w 01 12`;
do
     USER=user$i
     echo "copy certificates for" $USER
     mkdir /home/$USER/.kube
     cp /home/$GRANT_USER/.kube/ca.pem /home/$USER/.kube/ca.pem
     cp /home/$GRANT_USER/.kube/user.pem /home/$USER/.kube/$USER.pem
     cp /home/$GRANT_USER/.kube/user-key.pem /home/$USER/.kube/$USER-key.pem
     chmod 600 /home/$USER/.kube/*.pem
     chown $USER:$USER /home/$USER/.kube/*.pem
     echo "setting the context" $NAMESPACE/$CLUSTER/$USER "for" $USER
     NAMESPACE=project${USER:4:2}
     CLUSTER=secure-cluster
     su -c "kubectl config set-credentials $USER --client-certificate=$USER.pem --client-key=$USER-key.pem" -s /bin/bash $USER
     su -c "kubectl config set-cluster $CLUSTER --server=$SERVER --certificate-authority=ca.pem" -s /bin/bash $USER
     su -c "kubectl config set-context $NAMESPACE/$CLUSTER/$USER --cluster=$CLUSTER --namespace=$NAMESPACE --user=$USER" -s /bin/bash $USER
     su -c "kubectl config use-context $NAMESPACE/$CLUSTER/$USER" -s /bin/bash $USER
     echo "creating the namespace" $NAMESPACE
     su -c "kubectl create namespace $NAMESPACE" -s /bin/bash $USER
     su -c "kubectl label namespace $NAMESPACE type=project" -s /bin/bash $USER
     su -c "kubectl create quota besteffort --hard=pods=10" -s /bin/bash $USER
     su -c "kubectl describe namespace $NAMESPACE" -s /bin/bash $USER
done
