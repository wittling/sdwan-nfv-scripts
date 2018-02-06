#!/bin/bash

logger "gw_instantiate: INSTANTIATION of the Deflect"

logger "gw_instantiate: Hostname: ${hostname}"
logger "gw_instantiate: Hostname: ${wan1iface}"
logger "gw_instantiate: Hostname: ${wan2iface}"
logger "gw_instantiate: Hostname: ${laniface}"
logger "gw_instantiate: Data Port: ${portdata}" 
logger "gw_instantiate: CallP Port: ${portcallp}" 
logger "gw_instantiate: CallP Port: ${svrzabbix}" 
logger "gw_instantiate: CallP Port: ${vldinternal}" 
logger "gw_instantiate: CallP Port: ${svctyp}" 
logger "gw_instantiate: CallP Port: ${svcid}" 
logger "gw_instantiate: CallP Port: ${vlanid}" 

logger "gw_instantiate: IP Address: ${aaacorp-site1}" 

logger "gw_instantiate: INFO: Someone, OpenStack or the Orchestrator, has CloudInit resetting the sysctl.conf file." 
logger "gw_instantiate: INFO: We will attempt to set the socket buffer receive parm here."
logger "gw_instantiate: INFO: This will alleviate an alarm that complains about this parm being set too low."

# Obviously we need to be running this script as root to do this. Fortunately we are.
PARMPATH='/proc/sys/net/core/rmem_max'
echo 'net.core.rmem_max=2048000' >> /etc/sysctl.conf
sysctl -p 
if [ $? -eq 0 ]; then
   logger "gw_instantiate: INFO: Call to sysctl appears to be successful."
   logger "gw_instantiate: INFO: Verifying Socket Buffer Receive Parameter."
   echo "Socket Buffer Receive Parm rmem_max is now: `cat ${PARMPATH}`" | logger
else
   logger "gw_instantiate: WARN: Call to sysctl appears to have failed."
   logger "gw_instantiate: WARN: Please set net.core.rmem_max parameter to 2048000 manually to avoid alarm."
fi

# In case dvn is autostarted we will stop it until it is
# configured later on.
systemctl stop dvn

exit 0
