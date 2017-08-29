#!/bin/bash

# The first node up in a percona cluster needs to be cranked as a bootstrap service.
# This script will attempt to do that.

UNITNAME=mysql
# Process happens to be same in this case.
PROCESS=${UNITNAME}
SVCNAME="${UNITNAME}@bootstrap.service"

# Check and make sure mysql is not running. If it is, shut it down.
RC=`pgrep -lf ${PROCESS}`

# If we do not stop the service and just kill the process it may just restart on us.
# So make sure we put a stop on it from a service perspective first.
if [ ${RC} -eq 0 ]; then
   systemctl stop ${UNITNAME}
   sleep 3
fi   

# Check it again. If we see it kill it.
RC=`pgrep -lf ${PROCESS}`
if [ ${RC} -eq 0 ]; then
   pkill ${PROCESS}
   sleep 2
fi

# Start the bootstrap
systemctl start ${SVCNAME}
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   echo "INFO: Service ${SVCNAME} reported as active." 
   exit 0
else
   echo "ERROR: Service ${SVCNAME} NOT reported as active." 
   echo "ERROR: Manual intervention required. Service ${SVCNAME} may need to be started manually." 
   exit 1
fi
