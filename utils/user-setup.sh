#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure the private ssh key ~/.ssh/gcp.pem is present in user home dir
# Also ~/.ssh/config contains the "IdentityFile ~/.ssh/gcp.pem" string
#
sudo groupadd docker
for i in `seq -w 01 12`;
do
        USER=user$i;
        echo "add user         " $USER
        sudo useradd $USER
        sudo usermod -aG wheel $USER
        sudo usermod -aG docker $USER
        echo "copy ssh key for " $USER
        sudo mkdir /home/$USER/.ssh
        sudo cp ~/.ssh/authorized_keys /home/$USER/.ssh/authorized_keys
        sudo chmod 700 /home/$USER/.ssh
        sudo chmod 600 /home/$USER/.ssh/authorized_keys
        sudo chown $USER:$USER /home/$USER/.ssh
        sudo chown $USER:$USER /home/$USER/.ssh/authorized_keys
        echo "copy GCP key for " $USER
        sudo cp ~/.ssh/gcp.pem /home/$USER/.ssh/gcp.pem
        sudo cp ~/.ssh/config /home/$USER/.ssh/config
        sudo chown $USER:$USER /home/$USER/.ssh/gcp.pem
        sudo chown $USER:$USER /home/$USER/.ssh/config
        sudo chmod 600 /home/$USER/.ssh/config
        sudo chmod 600 /home/$USER/.ssh/gcp.pem
done
