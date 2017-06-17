#!/bin/bash -xv
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
sudo groupadd docker
for i in one two three four five six seven eight nine ten eleven twelve;
do
        USER=user-$i;
        echo "add user " $USER
        sudo useradd $USER
        echo "add password for user " $USER
        sudo passwd $USER
        sudo usermod -aG wheel $USER
        sudo usermod -aG docker $USER
        sudo mkdir /home/$USER/.ssh
        sudo cp ~/.ssh/authorized_keys /home/$USER/.ssh/authorized_keys
        sudo chmod 700 /home/$USER/.ssh
        sudo chmod 600 /home/$USER/.ssh/authorized_keys
        sudo chown $USER:$USER /home/$USER/.ssh
        sudo chown $USER:$USER /home/$USER/.ssh/authorized_keys

        sudo cp ~/.ssh/gcp.pem /home/$USER/.ssh/gcp.pem
        sudo cp ~/.ssh/config /home/$USER/.ssh/config
        sudo chown $USER:$USER /home/$USER/.ssh/gcp.pem
        sudo chown $USER:$USER /home/$USER/.ssh/config
        sudo chmod 600 /home/$USER/.ssh/config
        sudo chmod 600 /home/$USER/.ssh/gcp.pem

        sudo cp ./kube-context-setup.sh /home/$USER/kube-context-setup.sh
        sudo chown $USER:$USER /home/$USER/kube-context-setup.sh
        sudo chmod u+x /home/$USER/kube-context-setup.sh
        sudo su -c "/home/$USER/kube-context-setup.sh" -s /bin/bash $USER
done

# Make sure the private ssh key ~/.ssh/gcp.pem is present in user home dir
# Also ~/.ssh/config contains the "IdentityFile ~/.ssh/gcp.pem" string
