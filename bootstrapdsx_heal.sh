#!/bin/bash
#title           :bootstrapdsx_heal.sh
#author      :Wittling
#date            :2018
#version         :0.9    
#usage       :bash bootstrapdsx_heal.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# Trigger script upon a HEAL event.
# 
#==============================================================================
SCRIPTNAME="bootstrapdsx_heal.sh"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:HEAL LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/bootstrapdsx_heal.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

#set +x
exit 0
