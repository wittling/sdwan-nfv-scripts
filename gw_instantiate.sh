#!/bin/bash

#!/bin/bash
#set -x

# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

SCRIPTNAME="gw_configure"
SCRIPTDIR="/opt/openbaton/scripts"
logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
echo "====================================================" >> ${ENVFILE}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVFILE}
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env >> ${ENVFILE}
echo "====================================================" >> ${ENVFILE}

logger "${SCRIPTNAME}: INSTANTIATION of the Deflect"

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
