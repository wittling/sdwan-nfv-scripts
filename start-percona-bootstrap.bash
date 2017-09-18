#!/bin/bash

# The first node up in a percona cluster needs to be cranked as a bootstrap service.
# This script will attempt to do that.

UNITNAME=mysql
# Process happens to be same in this case.
PROCESS=${UNITNAME}
SVCNAME="${UNITNAME}@bootstrap.service"
DBINITIALIZE=12

# Go ahead and shut down the DPS Services so that we can start everything in proper sequence.
logger "Script: start-percona-bootstrap.bash: Stopping DPS Services so we can start Percona bootstrap"
systemctl stop dps.service
RC=`systemctl is-active dps.service`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: WARNING: dps.service did not stop. non-fatal. We will continue."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dps.service stopped."
fi

systemctl stop dart-rest.service
RC=`systemctl is-active dart-rest.service`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: WARNING: dart-rest.service did not stop. non-fatal. We will continue."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dart-rest.service stopped."
fi

systemctl stop dart3.service
RC=`systemctl is-active dart3.service`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: WARNING: dart3.service did not stop. non-fatal. We will continue."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dart3.service stopped."
fi

# Since we are not completely sure whether the DB is running in primary clustered mode or not, we will need to 
# shut down both and start ourselves as the bootstrap.

systemctl stop ${UNITNAME}
sleep 3
RC=`systemctl is-active ${UNITNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: ERROR: ${UNITNAME}.service did not stop. non-fatal. We will continue."
   exit 1
else
   logger "Script: start-percona-bootstrap.bash: INFO: ${UNITNAME}.service stopped."
fi

systemctl stop ${SVCNAME}
sleep 3
RC=`systemctl is-active ${SVCNAME}`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: ERROR: ${SVCNAME}.service did not stop. non-fatal. We will continue."
   exit 1
else
   logger "Script: start-percona-bootstrap.bash: INFO: ${SVCNAME}.service stopped."
fi

# Check and make sure mysql is not running. If it is, shut it down.
RC=`pgrep -lf ${PROCESS}`

# If we do not stop the service and just kill the process it may just restart on us.
# So make sure we put a stop on it from a service perspective first.
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: Detected mysql running. Attempting to stop..."
   systemctl stop ${UNITNAME}
   systemctl stop ${SVCNAME}
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

logger "Script: start-percona-bootstrap.bash: INFO: Percona takes a while to initialize..."
logger "Script: start-percona-bootstrap.bash: INFO: Waiting ${DBINITIALIZE}..."
sleep ${DBINITIALIZE} 

for i in 1 2 3; do
RC=`systemctl is-active ${SVCNAME}`
logger "Script: start-percona-bootstrap.bash: DEBUG: Return code from is-active on ${SVCNAME}: ${RC}"
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: Service ${SVCNAME} reported as active..."
   break
elif [ ${RC} -eq 1 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: Service ${SVCNAME} trying to activate..."
   sleep 2
else
   echo "ERROR: Service ${SVCNAME} NOT reported as active." 
   logger "Script: start-percona-bootstrap.bash: ERROR: Service ${SVCNAME} NOT reported as active..."
   if [ $i -eq 3 ]; then
      logger "Script: start-percona-bootstrap.bash: ERROR: Manual intervention required to start ${SVCNAME} properly!"
      logger "Script: start-percona-bootstrap.bash: ERROR: Giving up on required service ${SVCNAME}. Exiting."
      exit 1
   fi
fi
done

# Check and make sure the status is actually primary.
KEY=wsrep_cluster_status
STATUS=Primary
mysql --silent --host=localhost --user=root --password=$1 <<EOS | grep -i ${KEY} | awk '{print $2}' | grep -i ${STATUS}

SHOW STATUS LIKE 'wsrep_%';
EOS
if [ $? -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: Percona is running as a Primary Node!"
else
   logger "Script: start-percona-bootstrap.bash: ERROR: Percona is NOT running as a Primary Node!"
   exit 1
fi

# Now restart the DPS Services

logger "Script: start-percona-bootstrap.bash: INFO: Restarting dps.service after Percona Bootstrap startup."
systemctl start dps.service
sleep 3
RC=`systemctl is-active dps.service`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: dps.service restarted."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dps.service did NOT restart. Manual intervention required."
fi

systemctl start dart3.service
sleep 3
RC=`systemctl is-active dart3.service`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: dart3.service (node) restarted."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dart3.service (node) did NOT restart. Manual intervention required."
fi

systemctl start dart-rest.service
RC=`systemctl is-active dart-rest.service`
if [ ${RC} -eq 0 ]; then
   logger "Script: start-percona-bootstrap.bash: INFO: dart-rest.service (node) restarted."
else
   logger "Script: start-percona-bootstrap.bash: INFO: dart-rest.service (node) did NOT restart. Manual intervention required."
fi

exit 0
