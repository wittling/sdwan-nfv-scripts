#!/bin/bash
#title           :deflect_instantiate.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash deflect_instantiate.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is called whenever a deflect is instantiated.
#==============================================================================
SCRIPTNAME=${SCRIPTNAME}
# Print env out so we can see what is getting passed into us from orchestrator.
ENVOUT="/opt/openbaton/scripts/${SCRIPTNAME}.env"
echo "====================================================" >> ${ENVOUT}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVOUT}
env >> ${ENVOUT}
echo "" >> ${ENVOUT}
echo "====================================================" >> ${ENVOUT}

logger "${SCRIPTNAME}: INSTANTIATION of the Deflect"

logger "${SCRIPTNAME}: Hostname: ${hostname}"
logger "${SCRIPTNAME}: IP Address: ${dflnet}" 
logger "${SCRIPTNAME}: Traffic Interface: ${ifacetraffic}" 
logger "${SCRIPTNAME}: Data Port: ${portdata}" 
logger "${SCRIPTNAME}: CallP Port: ${portcallp}" 

logger "${SCRIPTNAME}: INFO: Something has CloudInit resetting the sysctl.conf file." 
logger "${SCRIPTNAME}: INFO: We will attempt to set the socket buffer receive parm here."
logger "${SCRIPTNAME}: INFO: This will alleviate an alarm that complains about this parm being set too low."

# Obviously we need to be running this script as root to do this. Fortunately we are.
PARMPATH='/proc/sys/net/core/rmem_max'
echo 'net.core.rmem_max=2048000' >> /etc/sysctl.conf
sysctl -p 
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}: INFO: Call to sysctl appears to be successful."
   logger "${SCRIPTNAME}: INFO: Verifying Socket Buffer Receive Parameter."
   echo "Socket Buffer Receive Parm rmem_max is now: `cat ${PARMPATH}`" | logger
else
   logger "${SCRIPTNAME}: WARN: Call to sysctl appears to have failed."
   logger "${SCRIPTNAME}: WARN: Please set net.core.rmem_max parameter to 2048000 manually to avoid alarm."
fi
exit 0
