#!/bin/bash

# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

#env
#set -x


# Originally we wanted to just swap an IP address and used sed as the way to do this. It did not
# take long before we had more parameters and quickly figured out that sed was NOT the way to edit
# parms in json files. So we ditched the sed and instead used this python script, which of course
# now means that this will not work if python is not installed on the target. The good news is that
# this script should work with python 2 or python 3. But we check first to make sure python is
# installed before proceeding.
function jsonParmSwap
{
   # Check for Python and see if it is installed (no sense wasting gas)
   logger "bootstrapdsx_configure: jsonParmSwap:INFO: Checking Python Version"
   pyver=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
   if [[ -z "$pyver" ]]; then
      logger "bootstrapdsx_configure: jsonParmSwap:ERROR: No Python Version!"
      return 1
   else
      logger "bootstrapdsx_configure: jsonParmSwap:INFO: Python Version: ${pyver}"
   fi
      
   FILENAME=""
   FILECODE=""

   if [ -z "$1" -o -z "$2" ]; then
      echo "Invalid Function Call replaceJsonParm: Required: FILECODE NEWIP"
      return 1
   fi

   case $1 in
      "CFGIP") 
           FILENAME=/usr/local/dvn/cfg/vtc_config.json
           NEWPARM=$2
           FILECODE=$1;;
      "CFGNIC") 
           FILENAME=/usr/local/dvn/cfg/vtc_config.json
           NEWPARM=$2
           FILECODE=$1;;
      "CFGMAC") 
           FILENAME=/usr/local/dvn/cfg/vtc_config.json
           NEWPARM=$2
           FILECODE=$1;;
      "CFGVTCNM") 
           FILENAME=/usr/local/dvn/cfg/vtc_config.json
           NEWPARM=$2
           FILECODE=$1;;
      "CFGVTCID") 
           FILENAME=/usr/local/dvn/cfg/vtc_config.json
           NEWPARM=$2
           FILECODE=$1;;
      *) return 1;;
   esac

   DIRNAME=`dirname ${FILENAME}`
   if [ ! -d ${DIRNAME} ]; then
      logger "bootstrapdsx_configure: jsonParmSwap: ERROR: Dir not found: ${DIRNAME}"
      return 1
   fi

   # TODO: If it is the same file name we can probably replace all of these parameters in one shot.
   if [ -f ${FILENAME} ]; then
      # Cleaner to drop into the directory when you are doing sed stuff
      pushd ${DIRNAME}

      # LOCALFILE=`basename ${FILENAME}`
      parse_json_script=$(mktemp parse_json.XXXX.py)

      if [ ${FILECODE} == "CFGNIC" ]; then
         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["nic"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "CFGMAC" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["mac"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "CFGIP" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["domains"][0]["dps_list"][0]["ip"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "CFGVTCNM" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["vtc_name"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      elif [ ${FILECODE} == "CFGVTCID" ]; then

         cat > "$parse_json_script" <<SCRIPT
#!/usr/bin/env python
import json
with open("${FILENAME}",'r+') as f:
    data=json.load(f)
    data["vtc_config"]["vtc_id"] = "${NEWPARM}"
    f.seek(0)
    json.dump(data, f, indent=4)
SCRIPT
      else
         logger "bootstrapdsx_configure: jsonParmSwap:ERROR: Invalid File Code."
         rm $parse_json_script
         popd
         return 1
      fi
         
      python $parse_json_script && rm $parse_json_script
      if [ $? -eq 0 ]; then
         logger "bootstrapdsx_configure: jsonParmSwap:INFO: Parm Replaced"
      else
         logger "bootstrapdsx_configure: jsonParmSwap:ERROR: Parm NOT Replaced"
         popd
         return 1
      fi   
   else
      logger "bootstrapdsx_configure: jsonParmSwap:ERROR:File Not Found:${FILENAME}"
      return 1
   fi
}

logger "bootstrapdsx_configure.bash: Greetings Deflect! I am Bootstrap DSX."
logger "bootstrapdsx_configure.bash: I see your Deflect Hostname has been assigned as: ${hostname}"
logger "bootstrapdsx_configure.bash: I see your Deflect IP has been assigned as: ${dflnet}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX IP Address is: ${bootstrapdsx_dsxnet}."
logger "bootstrapdsx_configure.bash: It appears you will using the traffic interface: ${ifacetraffic}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Control Plane Interface is: ${bootstrapdsx_ifacectlplane}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Registration Port is: ${bootstrapdsx_portreg}"
logger "bootstrapdsx_configure.bash: My REST API Port is: ${bootstrapdsx_portrest}"

# export the variables
export hostname
export dflnet
export bootstrapdsx_dsxnet
export bootstrapdsx_portreg
export bootstrapdsx_portrest
export ifacetraffic

systemctl stop dvn.service

logger "bootstrapdsx_configure: Changing IP Address in CFG: ${bootstrapdsx_dsxnet}" 
jsonParmSwap CFGIP ${bootstrapdsx_dsxnet}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_configure:INFO: IP ${bootstrapdsx_dsxnet} Replaced for file code: CFGIP."
else
   logger "bootstrapdsx_configure:ERROR: IP ${bootstrapdsx_dsxnet} NOT Replaced for file code CFGIP." 
   exit 1 
fi

# Just because a variable says we should be using interface ethx does not mean it is so. Check it.
if [ ! -d "/sys/class/net/${ifacetraffic}" ]; then
   logger "bootstrapdsx_configure:ERROR:NIC ${ifacetraffic} not enabled on this instance!" 
   exit 1
else
   logger "bootstrapdsx_configure: Changing nic in CFG: ${ifacetraffic}" 
   jsonParmSwap CFGNIC ${ifacetraffic}
   if [ $? -eq 0 ]; then
      logger "bootstrapdsx_configure:INFO: NIC ${ifacetraffic} Replaced for file code: CFGNIC ." 
   else
      logger "bootstrapdsx_configure:ERROR: NIC ${ifacetraffic} NOT Replaced for file code: CFGNIC." 
      exit 1 
   fi
fi

MAC=`cat /sys/class/net/${ifacetraffic}/address`
logger "bootstrapdsx_configure: Changing mac in CFG: ${MAC}" 
jsonParmSwap CFGMAC ${MAC}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_configure:INFO: MAC Replaced for file code: CFGMAC ." 
else
   logger "bootstrapdsx_configure:ERROR: MAC NOT Replaced for file code: CFGMAC." 
   exit 1 
fi

#NODENUM=`echo ${dflnet} | cut -f 4 -d "."`
NODENUM=`hostname -I | cut -f 4 -d "."`
export VTCNAME=OPNBTN${NODENUM}

logger "bootstrapdsx_configure: Changing vtcname in CFG: ${VTCNAME}" 
jsonParmSwap CFGVTCNM ${VTCNAME}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_configure:INFO: vtcname Replaced for file code: CFGVTCNM ." 
else
   logger "bootstrapdsx_configure:ERROR: vtcname NOT Replaced for file code: CFGVTCNM." 
   exit 1 
fi

logger "bootstrapdsx_configure: Changing vtcid in CFG: ${VTCNAME}" 
jsonParmSwap CFGVTCID ${VTCNAME}
if [ $? -eq 0 ]; then
   logger "bootstrapdsx_configure:INFO: vtcid Replaced for file code: CFGVTCID ." 
else
   logger "bootstrapdsx_configure:ERROR: vtcid NOT Replaced for file code: CFGVTCID." 
   exit 1 
fi


# Now restart the DVN 

logger "Script: bootstrapdsx_configure.bash:INFO: Stopping dvn.service after setting parameters."
systemctl stop dvn.service
OUTPUT=`systemctl is-active dvn.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_configure.sh:WARNING: dvn.service did not stop. non-fatal. We will continue."
else
   logger "Script: bootstrapdsx_configure.sh:INFO: dvn.service stopped."
fi

sleep 3

logger "Script: bootstrapdsx_configure.bash:INFO: Restarting dvn.service after setting parameters."
systemctl restart dvn.service
OUTPUT=`systemctl is-active dvn.service`
if [ $? -eq 0 ]; then
   logger "Script: bootstrapdsx_configure.bash:INFO: dvn.service restarted."
else
   logger "Script: bootstrapdsx_configure.bash:ERROR: dvn.service did NOT restart. Manual intervention required."
   exit 1 
fi

#set +x
exit 0
