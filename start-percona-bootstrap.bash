#!/bin/bash

# The first node up in a percona cluster needs to be cranked as a bootstrap service.
# This script will attempt to do that.

UNITNAME=mysql
# Process happens to be same in this case.
PROCESS=${UNITNAME}
SVCNAME="${UNITNAME}@bootstrap.service"

# Go ahead and shut down the DPS Services so that we can start everything in proper sequence.
logger "Script: start-percona-bootstrap.bash: Stopping DPS Services so we can start Percona bootstrap"
systemctl stop dps.service
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: WARNING: dps.service did not stop. non-fatal. We will continue."
fi

systemctl stop dart-rest.service
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: WARNING: dart-rest.service did not stop. non-fatal. We will continue."
fi

systemctl stop dart3.service
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: WARNING: dart3.service did not stop. non-fatal. We will continue."
fi

# Check and make sure mysql is not running. If it is, shut it down.
RC=`pgrep -lf ${PROCESS}`

# If we do not stop the service and just kill the process it may just restart on us.
# So make sure we put a stop on it from a service perspective first.
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: Detected mysql running. Attempting to stop..."
   systemctl stop ${UNITNAME}
   sleep 3
fi   

# Check it again. If we see it kill it.
RC=`pgrep -lf ${PROCESS}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: mysql STILL running. Attempting to kill it..."
   pkill ${PROCESS}
   sleep 2
fi

# Start the bootstrap
logger "Script: start-percona-bootstrap.bash: Attempting to start Percona as bootstrap..."
systemctl start ${SVCNAME}
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: Service ${SVCNAME} reported as active..."
   exit 0
else
   echo "ERROR: Service ${SVCNAME} NOT reported as active." 
   logger "Script: start-percona-bootstrap.bash: ERROR: Service ${SVCNAME} NOT reported as active..."
   logger "Script: start-percona-bootstrap.bash: ERROR: Manual intervention required to start ${SVCNAME} properly!"
   exit 1
fi

# Now restart the DPS Services

# Go ahead and shut down the DPS Services so that we can start everything in proper sequence.
logger "Script: start-percona-bootstrap.bash: INFO: Restarting DPS Services after Percona Bootstrap startup."
systemctl start dps.service
sleep 3
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: dps.service restarted."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dps.service did NOT restart. Manual intervention required."
fi

systemctl start dart3.service
sleep 3
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: dart3.service (node) restarted."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dart3.service (node) did NOT restart. Manual intervention required."
fi
systemctl start dart3.service
sleep 3

systemctl start dart-rest.service
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: dart-rest.service (node) restarted."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dart-rest.service (node) did NOT restart. Manual intervention required."
fi
