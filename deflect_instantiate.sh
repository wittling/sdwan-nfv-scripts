#!/bin/bash

logger "deflect_instantiate: INSTANTIATION of the Deflect"

logger "deflect_instantiate: Hostname: ${hostname}"
logger "deflect_instantiate: IP Address: ${dflnet}" 
logger "deflect_instantiate: Traffic Interface: ${ifacetraffic}" 
logger "deflect_instantiate: Data Port: ${portdata}" 
logger "deflect_instantiate: CallP Port: ${portcallp}" 

logger "deflect_instantiate: INFO: Someone, OpenStack or the Orchestrator, has CloudInit resetting the sysctl.conf file." 
logger "deflect_instantiate: INFO: We will attempt to set the socket buffer receive parm here."
logger "deflect_instantiate: INFO: This will alleviate an alarm that complains about this parm being set too low."

# Obviously we need to be running this script as root to do this. Fortunately we are.
PARMPATH='/proc/sys/net/core/rmem_max'
echo 'net.core.rmem_max=2048000' >> /etc/sysctl.conf
sysctl -p 
if [ $? -eq 0 ]; then
   logger "deflect_instantiate: INFO: Call to sysctl appears to be successful."
   logger "deflect_instantiate: INFO: Verifying Socket Buffer Receive Parameter."
   echo "Socket Buffer Receive Parm rmem_max is now: `cat ${PARMPATH}`" | logger
else
   logger "deflect_instantiate: WARN: Call to sysctl appears to have failed."
   logger "deflect_instantiate: WARN: Please set net.core.rmem_max parameter to 2048000 manually to avoid alarm."
fi
exit 0
