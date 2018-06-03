#!/bin/bash 
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Usage: sudo ./flush-secure-kube-context-setup.sh
#
for i in `seq -w 01 12`;
do
     USER=user$i
     NAMESPACE=project${USER:4:2}
     echo "Deleting the namespace" $NAMESPACE
     kubectl delete namespace $NAMESPACE 
done
