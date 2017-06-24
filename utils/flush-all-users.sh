#!/bin/bash
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
for i in `seq -w 01 12`;
do
  USER=user$i;
  echo "deleting user         " $USER
  sudo userdel -rf $USER
done
