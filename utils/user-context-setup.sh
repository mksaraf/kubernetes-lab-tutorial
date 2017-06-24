#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
# Make sure the ser kube-context-setup.sh script is in the home dir
#
for i in `seq -w 00 12`;
do
        USER=user$i;
        echo "copying context files for " $USER
        sudo cp ./kube-context-setup.sh /home/$USER/kube-context-setup.sh
        sudo chown $USER:$USER /home/$USER/kube-context-setup.sh
        sudo chmod u+x /home/$USER/kube-context-setup.sh
        echo "setting the kubernetes context for " $USER
        sudo su -c "/home/$USER/kube-context-setup.sh" -s /bin/bash $USER
done
