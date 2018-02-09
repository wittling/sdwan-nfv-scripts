#!/bin/bash
#title           :almostnothing.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash almostnothing.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# At the risk of a debate with physicists and the metaphysical, I decided
# that this script needed to be called almostnothing because it is not
# truly nothing. I
#
# It was initially used as a trigger debugging script just to make sure the
# scripts were getting fired and event notifications were working properly.
# 
# I still suggest and recommend using this script when there is an event that
# requires, well, almost nothing. That way you can make sure things are 
# firing properly.
#==============================================================================
SCRIPTNAME=almostnothing.bash
MSG="Script that does almost nothing"

# send string to std out and also stderr
echo "Script: $SCRIPTNAME: $MSG" 2>&1
# send same string to logger which puts it in syslog
logger "Script: $SCRIPTNAME: $MSG"

# Now we should be able to check and make sure these scripts are firing more effectively.
exit 0
