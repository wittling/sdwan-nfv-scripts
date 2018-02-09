#!/bin/bash
#title           :gw_configure.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash deflect_start.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is kind of important for the scaling function. 
# TODO: I plan to put together a unit file and run this as some kind of
# service so that some nodes load up CPU while others do not and so forth
# to ensure scaling is working correctly.
#==============================================================================

trap 'echo "Killing all dd processes"; pkill -f "dd if"; exit' INT

# Cores should always come in 1-4.
fullload()
{
   if [ $1 -eq 4 ]; then
      echo "Loading 4 Cores..."
      dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null &
   elif [ $1 -eq 3 ]; then
      echo "Loading 3 Cores..."
      dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null &
   elif [ $1 -eq 2 ]; then
      echo "Loading 2 Cores..."
      dd if=/dev/zero of=/dev/null | dd if=/dev/zero of=/dev/null &
   else
      echo "Loading Single Core..."
      dd if=/dev/zero of=/dev/null &
   fi
}

CORES=1
if [ -z $1 ]; then
   echo "Assuming 1 Core..."
elif [ $1 -lt 5 -a $1 -gt 0 ]; then
   echo "Assuming $1 Cores..."
   CORES=$1
else
   echo "Assuming 1 Core..."
fi

fullload $CORES
sleep 60
read
pkill -f "if dd"
exit
