#!/bin/bash

# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

SCRIPTNAME="bootstrapdsx_configure"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:Start LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}


# Originally we wanted to just swap an IP address and used sed as the way to do this. It did not
# take long before we had more parameters and quickly figured out that sed was NOT the way to edit
# parms in json files. So we ditched the sed and instead used this python script, which of course
# now means that this will not work if python is not installed on the target. The good news is that
# this script should work with python 2 or python 3. But we check first to make sure python is
# installed before proceeding.
function jsonParmSwap
{
   # Check for Python and see if it is installed (no sense wasting gas)
   logger "${SCRIPTNAME}: jsonParmSwap:INFO: Checking Python Version"
   pyver=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
   if [[ -z "$pyver" ]]; then
      logger "${SCRIPTNAME}: jsonParmSwap:ERROR: No Python Version!"
      return 1
   else
      logger "${SCRIPTNAME}: jsonParmSwap:INFO: Python Version: ${pyver}"
   fi
      
   FILENAME=""
   FILECODE=""

   if [ -z "$1" -o -z "$2" ]; then
      echo "Invalid Function Call replaceJsonParm: Required: FILECODE NEWIP"
      return 1
   fi

   case $1 in
      "CFGIP") ;&
      "CFGNIC") ;&
      "CFGMAC") ;&
      "CFGVTCNM") ;&
      "CFGVTCID") 
           FILENAME=/usr/local/dvn/cfg/vtc_config.json
           NEWPARM=$2
           FILECODE=$1;;
      *) return 1;;
   esac

   DIRNAME=`dirname ${FILENAME}`
   if [ ! -d ${DIRNAME} ]; then
      logger "${SCRIPTNAME}: jsonParmSwap: ERROR: Dir not found: ${DIRNAME}"
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
         logger "${SCRIPTNAME}: jsonParmSwap:ERROR: Invalid File Code."
         rm $parse_json_script
         popd
         return 1
      fi
         
      python $parse_json_script && rm $parse_json_script
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}: jsonParmSwap:INFO: Parm Replaced"
      else
         logger "${SCRIPTNAME}: jsonParmSwap:ERROR: Parm NOT Replaced"
         popd
         return 1
      fi   
   else
      logger "${SCRIPTNAME}: jsonParmSwap:ERROR:File Not Found:${FILENAME}"
      return 1
   fi
}

logger "${SCRIPTNAME}.sh: Greetings! I am your Bootstrap DSX."
logger "${SCRIPTNAME}.sh: My Bootstrap DSX IP Address is: ${bootstrapdsx_dsxnet}."
logger "${SCRIPTNAME}.sh: My Bootstrap DSX Control Plane Interface is: ${bootstrapdsx_ifacectlplane}"
logger "${SCRIPTNAME}.sh: My Bootstrap DSX Registration Port is: ${bootstrapdsx_portreg}"
logger "${SCRIPTNAME}.sh: My Bootstrap DSX REST Port is: ${bootstrapdsx_portra}"
logger "${SCRIPTNAME}.sh: The Service Group I have been told to initialize is: ${bootstrapdsx_svcgroup}"
logger "${SCRIPTNAME}.sh: The Service Group type I have been told to initialize is: ${bootstrapdsx_svcgrptyp}"


# export these.
export hostname
export bootstrapdsx_dsxnet
export bootstrapdsx_portreg
export bootstrapdsx_portra
export bootstrapdsx_svcgroup
export bootstrapdsx_svcgrptyp
export ifacetraffic

logger "${SCRIPTNAME}.sh: Enough about me. Let us discuss YOU..."
logger "${SCRIPTNAME}.sh: I see your Hostname has been assigned as: ${hostname}"
DVNELEMENT="vtc"

# Orchestrator does not pass the name into the env. But they DO use it in the hostname.
# We will take advantage of that.
ELEMENT=`hostname | cut -f 1 -d "-"`
# In case they ever change this we need to be careful and check.
if [ $? -eq 0 ]; then
   if [ ${ELEMENT} == "deflect" ]; then
      DVNELEMENT=${ELEMENT}
   elif [ ${ELEMENT} == "gw" ]; then
      DVNELEMENT=${ELEMENT}
   #elif [ ${ELEMENT} == "dvnclient" ]; then
   #   DVNELEMENT=${ELEMENT}
   else
      logger "${SCRIPTNAME}.sh:ERROR:Unrecognized element."
      exit 1
   fi
fi
    
systemctl stop dvn.service

logger "${SCRIPTNAME}: Changing IP Address in CFG: ${bootstrapdsx_dsxnet}" 
jsonParmSwap CFGIP ${bootstrapdsx_dsxnet}
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: IP ${bootstrapdsx_dsxnet} Replaced for file code: CFGIP."
else
   logger "${SCRIPTNAME}:ERROR: IP ${bootstrapdsx_dsxnet} NOT Replaced for file code CFGIP." 
   exit 1 
fi

# We should be passing in a var that tells us what interface to use as our traffic interface.
# If we do not get that, we could decide to die, or we could decide to be clever and use 
# the interface that is currently associated with the default route.
if [ -z ${ifacetraffic} ]; then
   logger "${SCRIPTNAME}:WARN:No traffic interface specified on this instance (ifacetraffic)!" 
   logger "${SCRIPTNAME}:WARN:Attempting to locate an interface that can be used with defgw." 
   DFLTNIC=`ip -4 r ls | grep default | grep -Po '(?<=dev )(\S+)'`
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:WARN:Found default gw interface ${DFLTNIC}.Attempting to use that." 
      ifacetraffic=${DFLTNIC}
   else
      logger "${SCRIPTNAME}:ERROR:Unable to find an appropriate interface for DVN traffic." 
      exit 1 
   fi
else
   if [ ${ifacetraffic} == "lo" ]; then
      logger "${SCRIPTNAME}:ERROR:Invalid loopback interface specified in ifacetraffic." 
      exit 1 
   fi
fi

# Just because a variable says we should be using interface ethx does not mean it is so. Check it.
if [ ! -d "/sys/class/net/${ifacetraffic}" ]; then
   logger "${SCRIPTNAME}:ERROR:NIC ${ifacetraffic} not valid or enabled on this instance!" 
   exit 1
else
   logger "${SCRIPTNAME}: Changing nic in CFG: ${ifacetraffic}" 
   jsonParmSwap CFGNIC ${ifacetraffic}
   if [ $? -eq 0 ]; then
      # If all looks good with the interface we can now set about the MAC Address
      logger "${SCRIPTNAME}:INFO: NIC ${ifacetraffic} Replaced for file code: CFGNIC ." 

      MAC=`cat /sys/class/net/${ifacetraffic}/address`
      logger "${SCRIPTNAME}: Changing mac in CFG: ${MAC}" 
      jsonParmSwap CFGMAC ${MAC}
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}:INFO: MAC Replaced for file code: CFGMAC ." 
      else
         logger "${SCRIPTNAME}:ERROR: MAC NOT Replaced for file code: CFGMAC." 
         exit 1 
      fi
   else
      logger "${SCRIPTNAME}:ERROR: NIC ${ifacetraffic} NOT Replaced for file code: CFGNIC." 
      exit 1 
   fi
fi

# If we have coded this right, if we get here we know we have a valid interface
# and MAC address and we have set that in our JSON file.
#
# Now it is time to figure out our IP. Why? Well that deserves a discussion. 
# 
# OpenBaton assigns every node a unique id and passes it into the environment.
# This environment is a temp shell environment btw - not the static one that
# you see if you log in later and dump the environment variables out.
#
# OpenBaton does not send the unique id in as its own env variable but rather uses
# it to name the host in a convention of VNFM name dashhyphen unique id. So we
# could grab that and use that as the way to provision our nodes uniquely. But
# that would or could be confusing since those IDs only mean something to the
# orchestrator. I think a better id is to grab the IP of the node and use that
# instead. Of course a box can have any number of IPs on it and even a single
# interface can have multiple IPs. So we need to choose the RIGHT ip address to
# use. And to do that requires some mojo. 
MYIP="127.0.0.1"
NTWK="local"
# We may have multiple IPs on a given interface! So this needs to be a loop.
for IP in `ip -4 a show ${ifacetraffic} | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`; do
   for LINE in `env`; do
      SRCH=`echo ${LINE} | grep ${IP}`
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}.sh:DEBUG: Found interface ${ifacetraffic} in environment."
         MYIP=${IP}
         NTWK=`echo ${SRCH} | cut -f 1 -d "="`
         if [ $? -eq 0 ]; then
            logger "${SCRIPTNAME}.sh:DEBUG: Interface ${ifacetraffic} assigned to ${NTWK}."
         else
            logger "${SCRIPTNAME}.sh:WARN: Cannot figure out network ${ifacetraffic} assigned to ."
         fi
         break
      fi
   done
   # This is a nested loop. Need to break out fully if we found it.
   if [ ${NTWK} != "local" ]; then
      break
   fi
done

#####################################
#if [ ! -z ${dflnet} ]; then
#   logger "${SCRIPTNAME}.sh:INFO: I see your IP has been assigned as: ${dflnet}"
#   export dflnet
#fi
#
#if [ ! -z ${aaacorp-site1net} ]; then
#   logger "${SCRIPTNAME}.sh: I see your IP has been assigned as: ${aaacorp-site1net}"
#fi
#
#if [ ! -z ${aaacorp-site2net} ]; then
#   logger "${SCRIPTNAME}.sh: I see your IP has been assigned as: ${aaacorp-site2net}"
#fi
#####################################

NODENUM=`echo ${MYIP} | cut -f3-4 -d "." | sed 's+\.+DT+'`
export VTCNAME=OPNBTN${NODENUM}

logger "${SCRIPTNAME}: Changing vtcname in CFG: ${VTCNAME}" 
jsonParmSwap CFGVTCNM ${VTCNAME}
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: vtcname Replaced for file code: CFGVTCNM ." 
else
   logger "${SCRIPTNAME}:ERROR: vtcname NOT Replaced for file code: CFGVTCNM." 
   exit 1 
fi

logger "${SCRIPTNAME}: Changing vtcid in CFG: ${VTCNAME}" 
jsonParmSwap CFGVTCID ${VTCNAME}
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: vtcid Replaced for file code: CFGVTCID ." 
else
   logger "${SCRIPTNAME}:ERROR: vtcid NOT Replaced for file code: CFGVTCID." 
   exit 1 
fi

# Now restart the DVN 
logger "Script: ${SCRIPTNAME}.sh:INFO: Stopping dvn.service after setting parameters."
systemctl stop dvn.service
OUTPUT=`systemctl is-active dvn.service`
if [ $? -eq 0 ]; then
   logger "Script: ${SCRIPTNAME}.sh:WARNING: dvn.service did not stop. non-fatal. We will continue."
else
   logger "Script: ${SCRIPTNAME}.sh:INFO: dvn.service stopped."
fi

sleep 3

logger "Script: ${SCRIPTNAME}.sh:INFO: Restarting dvn.service after setting parameters."
systemctl restart dvn.service
OUTPUT=`systemctl is-active dvn.service`
if [ $? -eq 0 ]; then
   logger "Script: ${SCRIPTNAME}.sh:INFO: dvn.service restarted."
else
   logger "Script: ${SCRIPTNAME}.sh:ERROR: dvn.service did NOT restart. Manual intervention required."
   exit 1 
fi

#set +x
exit 0
