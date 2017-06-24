#!/bin/bash -xv
#
# Copyright 2017 - Adriano Pezzuto
# https://github.com/kalise
#
for i in one two three four five six seven eight nine ten eleven twelve;
do
  USER=user-$i;
  sudo userdel -rf $USER
done
