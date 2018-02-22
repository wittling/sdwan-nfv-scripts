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

logger "${SCRIPTNAME}:INFO: INSTANTIATION of the Deflect"

logger "${SCRIPTNAME}:INFO: Hostname: ${hostname}"
logger "${SCRIPTNAME}:INFO: IP Address: ${dflnet}" 
logger "${SCRIPTNAME}:INFO: Traffic Interface: ${ifacetraffic}" 
logger "${SCRIPTNAME}:INFO: Data Port: ${portdata}" 
logger "${SCRIPTNAME}:INFO: CallP Port: ${portcallp}" 

logger "${SCRIPTNAME}:INFO: Something has CloudInit resetting the sysctl.conf file." 
logger "${SCRIPTNAME}:INFO: We will attempt to set the socket buffer receive parm here."
logger "${SCRIPTNAME}:INFO: This will alleviate an alarm that complains about this parm being set too low."

DVNSERVICENAME=dvn

# Obviously we need to be running this script as root to do this. Fortunately we are.
PARMPATH='/proc/sys/net/core/rmem_max'
echo 'net.core.rmem_max=2048000' >> /etc/sysctl.conf
sysctl -p 
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: Call to sysctl appears to be successful."
   logger "${SCRIPTNAME}:INFO: Verifying Socket Buffer Receive Parameter."
   echo "Socket Buffer Receive Parm rmem_max is now: `cat ${PARMPATH}`" | logger
else
   logger "${SCRIPTNAME}:WARN: Call to sysctl appears to have failed."
   logger "${SCRIPTNAME}:WARN: Please set net.core.rmem_max parameter to 2048000 manually to avoid alarm."
fi

# If dvn is autocranked we will want to stop it until the configure event cycle.
#RESP=`systemctl is-enabled ${DVNSERVICENAME}`
# to avoid shell issue
#if [ -z "${RESP}" ]; then
#   RESP=invalid
#fi
#if [ $? -eq 0 -a "${RESP}" == "enabled" ]; then
#   systemctl stop ${DVNSERVICENAME}
#else
#   if [ ${RESP} == "disabled" ]; then
#      logger "${SCRIPTNAME}:WARN: Service ${DVNSERVICENAME} disabled. Enabling."
#      systemctl enable ${DVNSERVICENAME}
#      if [ $? -ne 0 ]; then
#         logger "${SCRIPTNAME}:ERROR: Unable to enable service ${DVNSERVICENAME}. Enabling."
#         exit 1
#      fi  
#      # Enabling the service should not start it but we will do this just to be sure.
#      systemctl stop ${DVNSERVICENAME}
#   else
#      logger "${SCRIPTNAME}:ERROR: Service ${DVNSERVICENAME} unrecognized. Exiting."
#      exit 1
#   fi  
#fi
systemctl enable dvn
systemctl stop dvn

logger "${SCRIPTNAME}:INFO: End of Script. Return Code 0."
exit 0
