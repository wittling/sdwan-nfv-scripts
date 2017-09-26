#!/bin/bash


# This is a function because we may replace IPs in several files.
function replaceJsonParm
{
   FILENAME=""
   FILECODE=""

   if [ -z $1 -o -z $2 ]; then
      echo "Invalid Function Call replaceJsonParm: Required: FILECODE NEWIP"
      return 1
   fi

   case $1 in
      "RESTIP") 
           FILENAME=/usr/local/dart-rest/package.json
           NEWPARM=$2
           FILECODE=$1;;
      "RESTPORT") 
           FILENAME=/usr/local/dart-rest/package.json
           NEWPARM=$2
           FILECODE=$1;;
      "CFGTMPL") 
           FILENAME=/usr/local/dps/cfg/vtc_reg_templates/vtc_config_template.json
           NEWPARM=$2
           FILECODE=$1;;
      *) return 1;;
   esac

   DIRNAME=`dirname ${FILENAME}`
   if [ ! -d ${DIRNAME} ]; then
      logger "bootstrapdsx_instantiate: Dir not found: ${DIRNAME}"
      return 1
   fi

   if [ -f ${FILENAME} ]; then
      # Cleaner to drop into the directory when you are doing sed stuff
      pushd ${DIRNAME}
      cp ${TMPLT} ${TMPLT}.$$

      # This sed below is not working properly...bug in sed? Or an issue w the expression? Not sureyet.
      # sed -i 's+\"ip\"\:\"\([1-9]\)\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}+\"ip\"\:\'"$NEWPARM"'+' ${TMPLT}
   
      # Using sed to parse jsons is not a workable thing to do long-term. I will need to use a real json parser
      # of some kind. But I will use this sed for now.

      # This works - not pretty, not elegant, and not efficient, but it gets the job done.
      if [ ${FILECODE} == "CFGTMPL" ]; then
         (sed -i 's+\"ip\"\:\"\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\)+\"ip\"\:\"MARKER+' ${FILENAME} ; 
          sed -i 's+MARKER+'"$NEWPARM"'+' ${FILENAME})
      elif [ ${FILECODE} == "RESTIP" ]; then
         (sed -i 's+\"dsx_ip\"\: \"\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\)+\"ip\"\:\"MARKER+' ${FILENAME} ;
          sed -i 's+MARKER+'"$NEWPARM"'+' ${FILENAME})
      elif [ ${FILECODE} == "RESTPORT" ]; then
         (sed -i 's+\"dsx_ip\"\: \"\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\)+\"ip\"\:\"MARKER+' ${FILENAME} ;
          sed -i 's+MARKER+'"$NEWPARM"'+' ${FILENAME})
      else
         logger "bootstrapdsx_instantiate: replaceJsonParm: ERROR: No sed statement for file code ${FILECODE}."
         popd
         return 1
      fi

      if [ $? -eq 0 ]; then
         logger "bootstrapdsx_instantiate: replaceJsonParm: INFO: IP successfully replaced in ${FILENAME}"
         popd
      else
         logger "bootstrapdsx_instantiate: replaceJsonParm: ERROR: Error replacing IP in ${FILENAME}"
         popd
         return 1
      fi
   else
      logger "bootstrapdsx_instantiate: replaceJsonParm: ERROR: File not found: ${DIR}/${TMPLT}" 
      popd
      return 1
   fi
   return 0
}

function jsonParmSwap
{
   # Check for Python and see if it is installed (no sense wasting gas)
   logger "bootstrapdsx_instantiate: jsonParmSwap: INFO: Checking Python Version"
   pyver=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
   if [[ -z "$pyver" ]]; then
      logger "bootstrapdsx_instantiate: jsonParmSwap: ERROR: No Python Version!"
      return 1
   else
      logger "bootstrapdsx_instantiate: jsonParmSwap: INFO: Python Version: ${pyver}"
   fi
      
   FILENAME=""
   FILECODE=""

   if [ -z $1 -o -z $2 ]; then
      echo "Invalid Function Call replaceJsonParm: Required: FILECODE NEWIP"
      return 1
   fi

   case $1 in
      "RESTIP") 
           FILENAME=/usr/local/dart-rest/package.json
           NEWPARM=$2
           FILECODE=$1;;
      "RESTPORT") 
           FILENAME=/usr/local/dart-rest/package.json
           NEWPARM=$2
           FILECODE=$1;;
      "CFGTMPL") 
           FILENAME=/usr/local/dps/cfg/vtc_reg_templates/vtc_config_template.json
           NEWPARM=$2
           FILECODE=$1;;
      *) return 1;;
   esac

   DIRNAME=`dirname ${FILENAME}`
   if [ ! -d ${DIRNAME} ]; then
      logger "bootstrapdsx_instantiate: jsonParmSwap: ERROR: Dir not found: ${DIRNAME}"
      return 1
   fi

   if [ -f ${FILENAME} ]; then
      # Cleaner to drop into the directory when you are doing sed stuff
      pushd ${DIRNAME}

      # LOCALFILE=`basename ${FILENAME}`
      parse_json_script=$(mktemp parse_json.XXXX.py)

      if [ ${FILECODE} == "RESTIP" ]; then
         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["config"]["ip"] = ${NEWPARM}
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "RESTPORT" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["config"]["dsx_port"] = ${NEWPARM}
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "CFGTMPL" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["domains"][1][dps_list][1][ip] = ${NEWPARM}
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT

      else
         logger "bootstrapdsx_instantiate: jsonParmSwap: ERROR: Invalid File Code."
         rm $parse_json_script
         popd
         return 1
      fi
         
      python $parse_json_script && rm $parse_json_script
      if [ $? -eq 0 ]; then
         logger "bootstrapdsx_instantiate: jsonParmSwap: INFO: Parm Replaced"
      else
         logger "bootstrapdsx_instantiate: jsonParmSwap: ERROR: Parm NOT Replaced"
         popd
         return 1
      fi   
   fi
}

logger "bootstrapdsx_instantiate: INSTANTIATION of the Bootstrap DSX"

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
# -- COMMENTED OUT 
#KEY=wsrep_cluster_status
#STATUS=Primary
#mysql --silent --host=localhost --user=root --password=$1 <<EOS | grep -i ${KEY} | awk '{print $2}' | grep -i ${STATUS}
#
#SHOW STATUS LIKE 'wsrep_%';
#EOS
#if [ $? -eq 0 ]; then
#   logger "Script: bootstrapdsx_instantiate.bash: INFO: Percona is running as a Primary Node!"
#else
#   logger "Script: bootstrapdsx_instantiate.bash: ERROR: Percona is NOT running as a Primary Node!"
#   exit 1
#fi

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

logger "bootstrapdsx_instantiate: INSTANTIATION of the Bootstrap DSX"

logger "bootstrapdsx_instantiate: Hostname: ${hostname}"
logger "bootstrapdsx_instantiate: IP Address: ${dsxnet}" 
logger "bootstrapdsx_instantiate: Traffic Interface: ${ifacectlplane}" 
logger "bootstrapdsx_instantiate: Registration Port: ${portreg}" 
logger "bootstrapdsx_instantiate: REST API Port: ${portrest}" 
logger "bootstrapdsx_instantiate: REST Admin Port: ${portadmin}" 

logger "bootstrapdsx_instantiate: Changing IP Address in CFGTMPL: ${dsxnet}" 
#jsonParmSwap CFGTMPL ${dsxnet}
replaceJsonParm CFGTMPL ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate: INFO: IP $dsxnet Replaced for file code: CFGTMPL."
   systemctl restart dps
else
   logger "bootstrapdsx_instantiate: ERROR: IP $dsxnet NOT Replaced for file code CFGTMPL." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing IP Address in REST: ${dsxnet}" 
jsonParmSwap RESTIP ${dsxnet}
#replaceJsonParm RESTIP ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate: INFO: IP $dsxnet Replaced for file code: REST ." 
   systemctl restart dart-rest
else
   logger "bootstrapdsx_instantiate: ERROR: IP $dsxnet NOT Replaced for file code: REST." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing Port in REST: ${dsxnet}" 
jsonParmSwap RESTPORT ${portadmin}
#replaceJsonParm RESTPORT ${portadmin}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate: INFO: Port $portadmin Replaced for file code: REST ." 
   systemctl restart dart-rest
else
   logger "bootstrapdsx_instantiate: ERROR: Port $portadmin NOT Replaced for file code: REST." 
   exit 1 
fi

exit 0
