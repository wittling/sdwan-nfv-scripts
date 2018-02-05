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
   logger "bootstrapdsx_instantiate: jsonParmSwap:INFO: Checking Python Version"
   pyver=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
   if [[ -z "$pyver" ]]; then
      logger "bootstrapdsx_instantiate: jsonParmSwap:ERROR: No Python Version!"
      return 1
   else
      logger "bootstrapdsx_instantiate: jsonParmSwap:INFO: Python Version: ${pyver}"
   fi
      
   FILENAME=""
   FILEPARM=""

   if [ -z "$1" -o -z "$2" ]; then
      echo "Invalid Function Call replaceJsonParm: Required: FILEPARM PARM"
      return 1
   fi

   case $1 in
      "DARTIP") 
           FILENAME=/usr/local/dart/package.json
           NEWPARM=$2
           FILEPARM=$1;;
      "RESTIP") 
           FILENAME=/usr/local/dart-rest/package.json
           NEWPARM=$2
           FILEPARM=$1;;
      "DARTPORT") 
           FILENAME=/usr/local/dart/package.json
           NEWPARM=$2
           FILEPARM=$1;;
      "RESTPORT") 
           FILENAME=/usr/local/dart-rest/package.json
           NEWPARM=$2
           FILEPARM=$1;;
      "CFGTMPL") 
           FILENAME=/usr/local/dps/cfg/vtc_reg_templates/vtc_config_template.json
           NEWPARM=$2
           FILEPARM=$1;;
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

      if [ ${FILEPARM} == "RESTIP" -o ${FILEPARM} == "DARTIP" ]; then
         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["config"]["dsx_ip"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILEPARM} == "RESTPORT" -o ${FILEPARM} == "DARTPORT" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["config"]["dsx_port"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILEPARM} == "CFGTMPL" ]; then

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
         logger "bootstrapdsx_instantiate: jsonParmSwap:ERROR: Invalid File Code."
         rm $parse_json_script
         popd
         return 1
      fi
         
      python $parse_json_script 
      if [ $? -eq 0 ]; then
         logger "bootstrapdsx_instantiate: jsonParmSwap:INFO: Parm ${FILEPARM} Replaced in ${FILENAME}."
         rm $parse_json_script
      else
         logger "bootstrapdsx_instantiate: jsonParmSwap:ERROR: Parm ${FILEPARM} NOT Replaced in ${FILENAME}."
         logger "bootstrapdsx_instantiate: jsonParmSwap:INFO: Script $parse_json_script preserved."
         popd
         return 1
      fi   
   fi
}

logger "bootstrapdsx_instantiate:INFO:Instantiation of the Bootstrap DSX"

# The first node up in a percona cluster needs to be cranked as a bootstrap service.
# This script will attempt to do that.

UNITNAME=mysql
# Process happens to be same in this case.
PROCESS=${UNITNAME}
SVCNAME="${UNITNAME}@bootstrap.service"
DBINITIALIZE=8

# Go ahead and shut down the DPS Services so that we can start everything in proper sequence.
logger "Script: bootstrapdsx_instantiate.sh: Stopping DPS Services so we can start Percona bootstrap"
systemctl stop dps.service
OUTPUT=`systemctl is-active dps.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:WARNING: dps.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_instantiate.sh:INFO: dps.service stopped."
fi

systemctl stop dart-rest.service
OUTPUT=`systemctl is-active dart-rest.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:WARNING: dart-rest.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_instantiate.sh:INFO: dart-rest.service stopped."
fi

systemctl stop dart.service
OUTPUT=`systemctl is-active dart.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:WARNING: dart.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_instantiate.sh:INFO: dart.service stopped."
fi

# Since we are not completely sure whether the DB is running in primary clustered mode or not, we will need to 
# shut down both and start ourselves as the bootstrap.

systemctl stop ${UNITNAME}
sleep 3
OUTPUT=`systemctl is-active ${UNITNAME}`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:ERROR: ${UNITNAME}.service did not stop. non-fatal. We will continue."
   exit 1
else
   logger "Script: bootstrapdsx_instantiate.sh:INFO: ${UNITNAME}.service stopped."
fi

systemctl stop ${SVCNAME}
sleep 3
OUTPUT=`systemctl is-active ${SVCNAME}`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:ERROR: ${SVCNAME}.service did not stop. non-fatal. We will continue."
   exit 1
else
   logger "Script: bootstrapdsx_instantiate.sh:INFO: ${SVCNAME}.service stopped."
fi

# Check and make sure mysql is not running. If it is, shut it down.
OUTPUT=`pgrep -lf ${PROCESS}`

# If we do not stop the service and just kill the process it may just restart on us.
# So make sure we put a stop on it from a service perspective first.
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh: Detected mysql running. Attempting to stop..."
   systemctl stop ${UNITNAME}
   systemctl stop ${SVCNAME}
   sleep 3
fi   

# Check it again. If we see it kill it.
OUTPUT=`pgrep -lf ${PROCESS}`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh: mysql STILL running. Attempting to kill it..."
   pkill ${PROCESS}
   sleep 2
fi

# Start the bootstrap
logger "Script: bootstrapdsx_instantiate.sh: Attempting to start Percona as bootstrap..."
systemctl start ${SVCNAME}

logger "Script: bootstrapdsx_instantiate.sh:INFO: Percona takes a while to initialize..."
logger "Script: bootstrapdsx_instantiate.sh:INFO: Waiting ${DBINITIALIZE}..."
sleep ${DBINITIALIZE} 

for i in 1 2 3; do
OUTPUT=`systemctl is-active ${SVCNAME}`
logger "Script: bootstrapdsx_instantiate.sh:DEBUG: Return code from is-active on ${SVCNAME}: ${OUTPUT}"
RC=$?
if [ ${RC} -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:INFO: Service ${SVCNAME} reported as active..."
   break
elif [ ${RC} -eq 1 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:INFO: Service ${SVCNAME} trying to activate..."
   sleep 2
else
   echo "ERROR: Service ${SVCNAME} NOT reported as active." 
   logger "Script: bootstrapdsx_instantiate.sh:ERROR: Service ${SVCNAME} NOT reported as active..."
   if [ $i -eq 3 ]; then
      logger "Script: bootstrapdsx_instantiate.sh:ERROR: Manual intervention required to start ${SVCNAME} properly!"
      logger "Script: bootstrapdsx_instantiate.sh:ERROR: Giving up on required service ${SVCNAME}. Exiting."
      exit 1
   fi
fi
done

# Check and make sure the status is actually primary.
# -- COMMENTED OUT DUE TO PASSWD ON COMMAND LINE WARNING
# -- MAYBE I will put a binary together that checks on status
#KEY=wsrep_cluster_status
#STATUS=Primary
#mysql --silent --host=localhost --user=root --password=$1 <<EOS | grep -i ${KEY} | awk '{print $2}' | grep -i ${STATUS}
#
#SHOW STATUS LIKE 'wsrep_%';
#EOS
#if [ $? -eq 0 ]; then
#   logger "Script: bootstrapdsx_instantiate.sh: INFO: Percona is running as a Primary Node!"
#else
#   logger "Script: bootstrapdsx_instantiate.sh: ERROR: Percona is NOT running as a Primary Node!"
#   exit 1
#fi

logger "bootstrapdsx_instantiate: Checking Service Orchestration Parameters."

logger "bootstrapdsx_instantiate: Hostname: ${hostname}"
logger "bootstrapdsx_instantiate: IP Address: ${dsxnet}" 
logger "bootstrapdsx_instantiate: Traffic Interface: ${ifacectlplane}" 
logger "bootstrapdsx_instantiate: Registration Port: ${portreg}" 
logger "bootstrapdsx_instantiate: REST RA Port: ${portra}" 
logger "bootstrapdsx_instantiate: REST RW Port: ${portrw}" 
logger "bootstrapdsx_instantiate: Service Group: ${svcgroup}" 
logger "bootstrapdsx_instantiate: Service Group Type: ${svcgrptyp}" 
logger "bootstrapdsx_instantiate: Deflect Pool: ${poolid}" 

# Export these variables so that they can be passed to downstream dependencies out of this script.
export hostname
export dsxnet
export ifacectlplane
export portreg
export portra
export portrw
export svcgroup
export svcgrptyp

logger "bootstrapdsx_instantiate: Changing IP Address in CFGTMPL: ${dsxnet}" 
jsonParmSwap CFGTMPL ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate:INFO: IP $dsxnet Replaced for file code: CFGTMPL."
   systemctl restart dps
else
   logger "bootstrapdsx_instantiate:ERROR: IP $dsxnet NOT Replaced for file code CFGTMPL." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing IP Address in REST: ${dsxnet}" 
jsonParmSwap RESTIP ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate:INFO: IP $dsxnet Replaced for file code: REST ." 
else
   logger "bootstrapdsx_instantiate:ERROR: IP $dsxnet NOT Replaced for file code: REST." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing Port in REST: ${portra}" 
jsonParmSwap RESTPORT ${portra}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate:INFO: Port ${portra} Replaced for file code: REST ." 
   systemctl restart dart-rest
else
   logger "bootstrapdsx_instantiate:ERROR: Port ${portra} NOT Replaced for file code: REST." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing IP Address in DART: ${dsxnet}" 
jsonParmSwap DARTIP ${dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate:INFO: IP $dsxnet Replaced for file code: DART ." 
else
   logger "bootstrapdsx_instantiate:ERROR: IP $dsxnet NOT Replaced for file code: DART." 
   exit 1 
fi

logger "bootstrapdsx_instantiate: Changing Port in DART: ${portrw}" 
jsonParmSwap DARTPORT ${portrw}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate:INFO: Port ${portrw} Replaced for file code: DART ." 
   systemctl restart dart-rest
else
   logger "bootstrapdsx_instantiate:ERROR: Port ${portrw} NOT Replaced for file code: DART." 
   exit 1 
fi

# Now restart the DPS Services

logger "Script: bootstrapdsx_instantiate.sh:INFO: Restarting dps.service after Percona Bootstrap startup."
systemctl start dps.service
sleep 3
OUTPUT=`systemctl is-active dps.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:INFO: dps.service restarted."
else
   logger "Script: bootstrapdsx_instantiate.sh:ERROR: dps.service did NOT restart. Manual intervention required."
   exit 1 
fi

systemctl start dart.service
sleep 3
OUTPUT=`systemctl is-active dart.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:INFO: dart.service (node) restarted."
else
   logger "Script: bootstrapdsx_instantiate.sh:ERROR: dart.service (node) did NOT restart. Manual intervention required."
   exit 1 
fi

systemctl start dart-rest.service
OUTPUT=`systemctl is-active dart-rest.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_instantiate.sh:INFO: dart-rest.service (node) restarted."
else
   logger "Script: bootstrapdsx_instantiate.sh:ERROR: dart-rest.service (node) did NOT restart. Manual intervention required."
   exit 1 
fi

python3 -V
if [ $? -ne 0 ]; then
   logger "bootstrapdsx_instantiate:ERROR: Python 3 not installed on DSX" 
   exit 1
fi

RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"
if [ ! -d ${RESTCLTDIR} ]; then
   logger "bootstrapdsx_instantiate:ERROR: No rest client directory ${RESTCLTDIR} on DSX" 
   exit 1
fi

# NOTE that we do a pushd into the directory here. Which means we will pop from here on out at exit points.
pushd ${RESTCLTDIR}

DVNRESTENV=".dvnrestenv"
for file in "servicegroup.py" "deflectpool.py" ${DVNRESTENV}; do
   if [ ! -f ${RESTCLTDIR}/${file} ]; then
      logger "bootstrapdsx_instantiate:ERROR:File Not Found: ${file}." 
      popd 
      exit 1
   else
      if [ ! -x ${file} ]; then
         chmod +x ${file}
      fi
   fi
done

logger "bootstrapdsx_instantiate: INFO: Attempting to set REST API URL..." 
( sed -i 's+https\:\/\/\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\.\)\([0-9]\{1,3\}\)+https\:\/\/MARKER+' ${DVNRESTENV} ; sed -i 's+MARKER+'"${dsxnet}"'+' ${DVNRESTENV} )
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_instantiate:INFO: Sourcing rest environment..." 
   source "${DVNRESTENV}" 
else
   logger "bootstrapdsx_instantiate:ERROR: Error setting REST API URL." 
   popd
   exit 1
fi

SLEEPTIME=4
sleep ${SLEEPTIME}
PROVSUCCESS=false
for i in 1 2 3; do
   case "$i" in 
      1) SLEEPTIME=$[SLEEPTIME+4] ;;
      2) SLEEPTIME=$[SLEEPTIME+8] ;;
      3) SLEEPTIME=$[SLEEPTIME+16] ;;
      *) ;;
   esac

   logger "bootstrapdsx_instantiate: INFO: Attempting to provision new ${svcgroup} service group." 
   (python3 servicegroup.py --operation provision --grpid ${svcgroup} --mnemonic ${svcgroup} --grptyp ${svcgrptyp} 1>servicegroup.py.log 2>&1)
   if [ $? -eq 0 ]; then
      logger "bootstrap_instantiate:INFO: Service Group ${svcgroup} provisioned!"
      PROVSUCCESS=true
      break
   elif [ $? -eq 4 ]; then
      logger "bootstrap_instantiate:INFO: Service Group ${svcgroup} already pre-provisioned (assumed correct)."
      PROVSUCCESS=true
      break
   else
      logger "bootstrap_instantiate:INFO: Unable to provision Service Group ${svcgroup}. Attempt: $i: Shell Code: $?"
      logger "bootstrap_instantiate:INFO: DBMgr may not be up yet. So we will sleep ${SLEEPTIME} secs and retry."
      sleep ${SLEEPTIME}
   fi
done

if [ ! ${PROVSUCCESS} ]; then
   logger "bootstrap_instantiate:INFO: Unable to provision Service Group ${svcgroup}. Please check logs."
   popd
   exit 1
fi

logger "bootstrap_instantiate:INFO: Provisioning Deflect Pool ${svcgroup} and adding to Service Group ${svcgroup}."
(python3 deflectpool.py --operation provision --poolid ${svcgroup} --mnemonic ${svcgroup} --targethigh 1 --targetlow 1
--minchannels 1 --directchannels 0 --selectsize 1 --rollinterval 5 --lowbandwidth "no" 1>deflectpool.py.log 2>&1)
if [ $? -eq 0 ]; then
   logger "bootstrap_instantiate:INFO: Deflect Pool ${svcgroup} properly provisioned!"
elif [ $? -eq 4 ]; then
   logger "bootstrap_instantiate:INFO: Deflect Pool already provisioned (assumed correct)."
else
   # The fact that we have svcgroup down below in var is not an error. We use the same name for group and pool.
   logger "bootstrap_instantiate:ERROR: Error occured in attempt to provision Deflect Pool ${svcgroup}. Shell Code: $?"
   popd
   exit 1
fi

logger "bootstrapdsx_instantiate:INFO: End of Script: Return Code 0" 
exit 0
