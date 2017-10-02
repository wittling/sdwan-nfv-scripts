#!/bin/bash

# Originally we wanted to just swap an IP address and used sed as the way to do this. It did not
# take long before we had more parameters and quickly figured out that sed was NOT the way to edit
# parms in json files. So we ditched the sed and instead used this python script, which of course
# now means that this will not work if python is not installed on the target. The good news is that
# this script should work with python 2 or python 3. But we check first to make sure python is
# installed before proceeding.
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
    data["config"]["dsx_ip"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "RESTPORT" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["config"]["dsx_port"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "CFGTMPL" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["domains"][0]["dps_list"][0]["ip"] = "${NEWPARM}"
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
logger "bootstrapdsx_instantiate: REST RA Port: ${portra}" 
logger "bootstrapdsx_instantiate: REST RW Port: ${portrw}" 
logger "bootstrapdsx_instantiate: Service Group: ${svcgroup}" 

logger "bootstrapdsx_instantiate: Changing IP Address in CFGTMPL: ${dsxnet}" 
jsonParmSwap CFGTMPL ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate: INFO: IP $dsxnet Replaced for file code: CFGTMPL."
   systemctl restart dps
else
   logger "bootstrapdsx_instantiate: ERROR: IP $dsxnet NOT Replaced for file code CFGTMPL." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing IP Address in REST: ${dsxnet}" 
jsonParmSwap RESTIP ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate: INFO: IP $dsxnet Replaced for file code: REST ." 
else
   logger "bootstrapdsx_instantiate: ERROR: IP $dsxnet NOT Replaced for file code: REST." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing Port in REST: ${portrestapi}" 
jsonParmSwap RESTPORT ${portra}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate: INFO: Port $portadmin Replaced for file code: REST ." 
   systemctl restart dart-rest
else
   logger "bootstrapdsx_instantiate: ERROR: Port $portadmin NOT Replaced for file code: REST." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Attempting to provision service group via REST interface" 
python3 -V
if [ $? -eq 0 ]; then
   RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"
   if [ -d ${RESTCLTDIR} ]; then
      if [ -f servicegroup.py ]; then
         if [ ! -x servicegroup.py ]; then
            chmod +x servicegroup.py
         fi
         pushd
         if [ -f .dvnrestenv ]; then
            echo "export DVNREST_URL=https:\/\/${dsxnet}\:3001" >> .dvnrestenv
            source .dvnrestenv
         else
            logger "bootstrapdsx_instantiate: ERROR: No environment file for rest API." 
            popd
            exit 1
         fi

         logger "bootstrapdsx_instantiate: INFO: Attempting to provision new OPENBATON service group." 
         (python3 servicegroup.py OPENBATON OPENBATON l3mlx)
         if [ $? -eq 0 ]; then
            logger "bootstrap_instantiate" INFO: Service Group OPENBATON provisioned!"
         elif [ $? -eq 4 ]; then
            logger "bootstrap_instantiate" INFO: Service Group OPENBATON already provisioned (assumed correct)."
         else
            logger "bootstrap_instantiate" ERROR: Error occured in attempt to provision Service Group."
            popd
            exit 1
         fi

         if [ -f deflectpool.py ]; then
            if [ ! -x deflectpool.py ]; then
               chmod +x deflectpool.py
            fi
            logger "bootstrap_instantiate" INFO: Provisioning Deflect Pool OPENBATON and adding to Service Group OPENBATON."
            (python3 deflectpool.py OPENBATON OPENBATON 1 1 1 0 1 5 no)
            if [ $? -eq 0 ]; then
               logger "bootstrap_instantiate" INFO: Deflect Pool OPENBATON properly provisioned!"
            elif [ $? -eq 4 ]; then
               logger "bootstrap_instantiate" INFO: Deflect Pool already provisioned (assumed correct)."
            popd
         else
            logger "bootstrap_instantiate" ERROR: Error occured in attempt to provision Service Group."
            popd
            exit 1
         fi
      else
         logger "bootstrapdsx_instantiate: ERROR: No servicegroup.py script." 
         popd
         exit 1
      fi
   else
      logger "bootstrapdsx_instantiate: ERROR: No rest client directory ${RESTCLTDIR} on DSX" 
      popd
      exit 1
   fi
   logger "bootstrapdsx_instantiate: ERROR: Python 3 not installed on DSX" 
   popd
   exit 1
fi

exit 0
