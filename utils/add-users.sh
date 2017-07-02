#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure the private ssh key ~/.ssh/gcp.pem is present in granting user home dir
# Also ~/.ssh/config contains the "IdentityFile ~/.ssh/gcp.pem" string
#
# Usage: sudo ./add-users.sh $(whoami)
#
if [[ $# -eq 0 ]] ; then
    echo "Please, provide a granting user"
    exit 1
fi
GRANT_USER=$1
echo "Granting user is " $GRANT_USER
sudo groupadd docker
for i in `seq -w 01 12`;
do
        USER=user$i;
        echo
        echo "add user         " $USER
        useradd $USER
        echo "set password for " $USER
        echo $USER:password | chpasswd
        usermod -aG wheel $USER
        usermod -aG docker $USER
        echo "copy ssh key for " $USER
        mkdir /home/$USER/.ssh
        chmod 700 /home/$USER/.ssh
        chown $USER:$USER /home/$USER/.ssh
        cp /home/$GRANT_USER/.ssh/authorized_keys /home/$USER/.ssh/authorized_keys
        chmod 600 /home/$USER/.ssh/authorized_keys
        chown $USER:$USER /home/$USER/.ssh/authorized_keys
        echo "copy GCP key for " $USER
        cp /home/$GRANT_USER/.ssh/gcp.pem /home/$USER/.ssh/gcp.pem
        chmod 600 /home/$USER/.ssh/gcp.pem
        chown $USER:$USER /home/$USER/.ssh/gcp.pem
        echo "copy ssh config  " $USER
        cp /home/$GRANT_USER/.ssh/config /home/$USER/.ssh/config
        chmod 600 /home/$USER/.ssh/config
        chown $USER:$USER /home/$USER/.ssh/config
done
