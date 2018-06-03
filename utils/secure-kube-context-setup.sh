#!/bin/bash 
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure certificates: ca.pem, client.pem, client-key.pem are in the ~/.kube home dir of granting user
# Usage: sudo ./secure-kube-context-setup.sh $(whoami) <HOST> <PORT>
# e.g sudo ./secure-kube-context-setup.sh $(whoami) kubernetes 6443
#
GRANT_USER=$1
echo "Granting user is " $GRANT_USER
SERVER=https://$2:$3
for i in `seq -w 01 12`;
do

     USER=user$i
     echo "create token for" $USER
     TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
     echo $TOKEN,$USER,100$i >> /etc/kubernetes/pki/tokens.csv
     
     echo "create kubectl env for user" $USER
     mkdir /home/$USER/.kube
     chown -R $USER:$USER /home/$USER/.kube
     
     CLUSTER=kubernetes
     NAMESPACE=project${USER:4:2}
     echo "creating the namespace" $NAMESPACE
     cat > namespace.yaml << EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    type: project
EOF

     cat > namespace-quota.yaml << EOF
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${NAMESPACE}-quota
  namespace: ${NAMESPACE}
spec:
  hard:
    pods: 16
EOF

     cat > tenant-admin-role-binding.yaml << EOF
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: ${NAMESPACE}:admin
  namespace: ${NAMESPACE}
subjects:
- kind: User
  name: ${USER}
  namespace: ${NAMESPACE}
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF

     kubectl create -f namespace.yaml
     kubectl create -f namespace-quota.yaml
     kubectl create -f tenant-admin-role-binding.yaml
     rm -f namespace.yaml namespace-quota.yaml tenant-admin-role-binding.yaml

     echo "setting the context" $NAMESPACE/$CLUSTER/$USER "for" $USER
     su -c "kubectl config set-credentials $USER --token=$TOKEN" -s /bin/bash $USER
     su -c "kubectl config set-cluster $CLUSTER --server=$SERVER --certificate-authority=/etc/kubernetes/pki/ca.pem --embed-certs=true" -s /bin/bash $USER
     su -c "kubectl config set-context $NAMESPACE/$CLUSTER/$USER --cluster=$CLUSTER --namespace=$NAMESPACE --user=$USER" -s /bin/bash $USER
     su -c "kubectl config use-context $NAMESPACE/$CLUSTER/$USER" -s /bin/bash $USER

done
