#!/bin/bash
#set -x

# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

SCRIPTNAME="l3gw_configure"
SCRIPTDIR="/opt/openbaton/scripts"

logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

# Print env out so we can see what is getting passed into us from orchestrator.
ENVOUT="/opt/openbaton/scripts/${SCRIPTNAME}.env"
echo "====================================================" >> ${ENVOUT}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVOUT}
env >> ${ENVOUT}
echo "" >> ${ENVOUT}
echo "====================================================" >> ${ENVOUT}

logger "${SCRIPTNAME}: Greetings Bootstrap DSX! I am a Gateway."
logger "${SCRIPTNAME}: I see your IP Address is: ${dsxnet}"
logger "${SCRIPTNAME}: I see your hostname is: ${hostname}"
logger "${SCRIPTNAME}: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "${SCRIPTNAME}: I will be sending data on port: ${gw_portdata}" 
logger "${SCRIPTNAME}: I will be sending callp on port: ${gw_portcallp}" 
logger "${SCRIPTNAME}: I will be using svc group: ${svcgroup}" 
logger "${SCRIPTNAME}: I will be using deflect pool id: ${poolid}" 
logger "${SCRIPTNAME}: My WAN 1 Interface is: ${wan1iface}" 
logger "${SCRIPTNAME}: My WAN 2 Interface is: ${wan2iface}" 
logger "${SCRIPTNAME}: My LAN Interface is: ${laniface}" 
logger "${SCRIPTNAME}: My VLD Interface for internal network is: ${vldinternal}" 
logger "${SCRIPTNAME}: The Service Type I will attempt to provision is: ${svctyp}" 
logger "${SCRIPTNAME}: The Service ID I will attempt to provision is: ${svcid}" 
logger "${SCRIPTNAME}: The VLAN Id I will attempt to provision is: ${vlanid}" 

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp
export svcgroup
export poolid
export wan1iface
export wan2iface
export laniface
export vldinternal
export svctyp
export svcid
export vlanid

if [ ! -d "${SCRIPTDIR}" ]; then
   logger "${SCRIPTNAME}:ERROR:Directory Not Found:${SCRIPTDIR}" 
   exit 1
fi

GW_COMMON_SCRIPT="gw_configure.sh"
logger "${SCRIPTNAME}: Looking for ${GW_COMMON_SCRIPT}." 
if [ ! -f "${SCRIPTDIR}/${GW_COMMON_SCRIPT}" ]; then
   logger "${SCRIPTNAME}:ERROR:File Not Found:${SCRIPTDIR}/${GW_COMMON_SCRIPT}"
   exit 1
fi

if [ ! -x "${SCRIPTDIR}/${GW_COMMON_SCRIPT}" ]; then
   chmod +x  ${SCRIPTDIR}/${GW_COMMON_SCRIPT} 
fi

source ${SCRIPTDIR}/${GW_COMMON_SCRIPT}
if [ $? -ne 0 ]; then
   logger "${SCRIPTNAME}:ERROR:Script Failed:${SCRIPTDIR}/${GW_COMMON_SCRIPT}"
else
   logger "${SCRIPTNAME}:ERROR:Script Succeeded:${SCRIPTDIR}/${GW_COMMON_SCRIPT}"
fi  
