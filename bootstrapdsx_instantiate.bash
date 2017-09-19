#!/bin/bash

# The first node up in a percona cluster needs to be cranked as a bootstrap service.
# This script will attempt to do that.

UNITNAME=mysql
# Process happens to be same in this case.
PROCESS=${UNITNAME}
SVCNAME="${UNITNAME}@bootstrap.service"
DBINITIALIZE=12

# Go ahead and shut down the DPS Services so that we can start everything in proper sequence.
logger "Script: bootstrapdsx_instantiate.bash: Stopping DPS Services so we can start Percona bootstrap"
systemctl stop dps.service
OUTPUT=`systemctl is-active dps.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: WARNING: dps.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dps.service stopped."
fi

systemctl stop dart-rest.service
OUTPUT=`systemctl is-active dart-rest.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: WARNING: dart-rest.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dart-rest.service stopped."
fi

systemctl stop dart3.service
OUTPUT=`systemctl is-active dart3.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: WARNING: dart3.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dart3.service stopped."
fi

# Since we are not completely sure whether the DB is running in primary clustered mode or not, we will need to 
# shut down both and start ourselves as the bootstrap.

systemctl stop ${UNITNAME}
sleep 3
OUTPUT=`systemctl is-active ${UNITNAME}`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: ERROR: ${UNITNAME}.service did not stop. non-fatal. We will continue."
   exit 1
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: ${UNITNAME}.service stopped."
fi

systemctl stop ${SVCNAME}
sleep 3
OUTPUT=`systemctl is-active ${SVCNAME}`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: ERROR: ${SVCNAME}.service did not stop. non-fatal. We will continue."
   exit 1
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: ${SVCNAME}.service stopped."
fi

# Check and make sure mysql is not running. If it is, shut it down.
OUTPUT=`pgrep -lf ${PROCESS}`

# If we do not stop the service and just kill the process it may just restart on us.
# So make sure we put a stop on it from a service perspective first.
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: Detected mysql running. Attempting to stop..."
   systemctl stop ${UNITNAME}
   systemctl stop ${SVCNAME}
   sleep 3
fi   

# Check it again. If we see it kill it.
OUTPUT=`pgrep -lf ${PROCESS}`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: mysql STILL running. Attempting to kill it..."
   pkill ${PROCESS}
   sleep 2
fi

# Start the bootstrap
logger "Script: bootstrapdsx_instantiate.bash: Attempting to start Percona as bootstrap..."
systemctl start ${SVCNAME}

logger "Script: bootstrapdsx_instantiate.bash: INFO: Percona takes a while to initialize..."
logger "Script: bootstrapdsx_instantiate.bash: INFO: Waiting ${DBINITIALIZE}..."
sleep ${DBINITIALIZE} 

for i in 1 2 3; do
OUTPUT=`systemctl is-active ${SVCNAME}`
logger "Script: bootstrapdsx_instantiate.bash: DEBUG: Return code from is-active on ${SVCNAME}: ${OUTPUT}"
RC=$?
if [ ${RC} -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: INFO: Service ${SVCNAME} reported as active..."
   break
elif [ ${RC} -eq 1 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: INFO: Service ${SVCNAME} trying to activate..."
   sleep 2
else
   echo "ERROR: Service ${SVCNAME} NOT reported as active." 
   logger "Script: bootstrapdsx_instantiate.bash: ERROR: Service ${SVCNAME} NOT reported as active..."
   if [ $i -eq 3 ]; then
      logger "Script: bootstrapdsx_instantiate.bash: ERROR: Manual intervention required to start ${SVCNAME} properly!"
      logger "Script: bootstrapdsx_instantiate.bash: ERROR: Giving up on required service ${SVCNAME}. Exiting."
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
   logger "Script: bootstrapdsx_instantiate.bash: INFO: Percona is running as a Primary Node!"
else
   logger "Script: bootstrapdsx_instantiate.bash: ERROR: Percona is NOT running as a Primary Node!"
   exit 1
fi

# Now restart the DPS Services

logger "Script: bootstrapdsx_instantiate.bash: INFO: Restarting dps.service after Percona Bootstrap startup."
systemctl start dps.service
sleep 3
OUTPUT=`systemctl is-active dps.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dps.service restarted."
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dps.service did NOT restart. Manual intervention required."
fi

systemctl start dart3.service
sleep 3
OUTPUT=`systemctl is-active dart3.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dart3.service (node) restarted."
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dart3.service (node) did NOT restart. Manual intervention required."
fi

systemctl start dart-rest.service
OUTPUT=`systemctl is-active dart-rest.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dart-rest.service (node) restarted."
else
   logger "Script: bootstrapdsx_instantiate.bash: INFO: dart-rest.service (node) did NOT restart. Manual intervention required."
fi

exit 0
#!/bin/bash

logger "bootstrapdsx_instantiate: INSTANTIATION of the Deflect"

logger "bootstrapdsx_instantiate: Hostname: ${hostname}"
logger "bootstrapdsx_instantiate: IP Address: ${dsxnet}" 
logger "bootstrapdsx_instantiate: Traffic Interface: ${ifacectlplane}" 
logger "bootstrapdsx_instantiate: Reserved: ${reserved}" 
