#!/bin/bash

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
