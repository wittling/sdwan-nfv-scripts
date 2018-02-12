#!/bin/bash
#title           :l3gw_instantiate.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash l3gw_instantiate.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is invoked for each instantiation of the gateway if so specified.
#==============================================================================
#set -x

SCRIPTNAME="l3gw_instantiate"
SCRIPTDIR="/opt/openbaton/scripts"
logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
echo "====================================================" >> ${ENVFILE}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVFILE}
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env >> ${ENVFILE}
echo "====================================================" >> ${ENVFILE}

logger "${SCRIPTNAME}: INSTANTIATION Script"

logger "${SCRIPTNAME}: Hostname: ${hostname}"
logger "${SCRIPTNAME}: Hostname: ${wan1iface}"
logger "${SCRIPTNAME}: Hostname: ${wan2iface}"
logger "${SCRIPTNAME}: Hostname: ${laniface}"
logger "${SCRIPTNAME}: Data Port: ${portdata}" 
logger "${SCRIPTNAME}: CallP Port: ${portcallp}" 
logger "${SCRIPTNAME}: Zabbix Server: ${svrzabbix}" 
logger "${SCRIPTNAME}: Internal VLD: ${vldinternal}" 
logger "${SCRIPTNAME}: Service Type: ${svctyp}" 
logger "${SCRIPTNAME}: Service ID: ${svcid}" 
logger "${SCRIPTNAME}: VLAN ID: ${vlanid}" 

logger "${SCRIPTNAME}: IP Address: ${aaacorp-site1}" 

logger "${SCRIPTNAME}: INFO: A process is resetting the sysctl.conf file." 
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

# In case dvn is autostarted we will stop it until it is
# configured later on.
systemctl stop dvn

exit 0
