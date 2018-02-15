#!/bin/bash
#title           :bootstrapdsx_configure.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash bootstrapdsx_configure.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.
#==============================================================================
#env
#set -x
SCRIPTNAME="bootstrapdsx_configure"
logger "${SCRIPTNAME}:INFO: Configure LifeCycle Event Triggered!"

SCRIPTDIR="/opt/openbaton/scripts"
if [ ! -d ${SCRIPTDIR} ]; then
   logger "${SCRIPTNAME}:WARN: Directory Not Found. Setting SCRIPTDIR to:${SCRIPTDIR}."
   SCRIPTDIR=${PWD}
fi

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env.$$"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
echo "====================================================" >> ${ENVFILE}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVFILE}
env | sort >> ${ENVFILE}
echo "====================================================" >> ${ENVFILE}

logger "${SCRIPTNAME}:INFO: Greetings! I am your Bootstrap DSX reporting in."
logger "${SCRIPTNAME}:INFO: My Bootstrap DSX IP Address is: ${bootstrapdsx_dsxnet}."
logger "${SCRIPTNAME}:INFO: My Bootstrap DSX Control Plane Interface is: ${bootstrapdsx_ifacectlplane}"
logger "${SCRIPTNAME}:INFO: My Bootstrap DSX Registration Port is: ${bootstrapdsx_portreg}"
logger "${SCRIPTNAME}:INFO: My Bootstrap DSX REST Port is: ${bootstrapdsx_portra}"
logger "${SCRIPTNAME}:INFO: My default Service Group I will initialize is: ${bootstrapdsx_svcgroup}"
logger "${SCRIPTNAME}:INFO: My default Service Group type I will initialize is: ${bootstrapdsx_svcgrptyp}"

logger "${SCRIPTNAME}:INFO: Enough about me. Here is what I see about YOU."
logger "${SCRIPTNAME}:INFO: The wan1iface value is: ${wan1iface}"
logger "${SCRIPTNAME}:INFO: The wan2iface value is: ${wan2iface}"
logger "${SCRIPTNAME}:INFO: The laniface value is: ${laniface}"
logger "${SCRIPTNAME}:INFO: The port data value is: ${portdata}"
logger "${SCRIPTNAME}:INFO: The port callp value is: ${portcallp}"
logger "${SCRIPTNAME}:INFO: The svctyp value is: ${svctyp}"
logger "${SCRIPTNAME}:INFO: The svcid value is: ${svcid}"
logger "${SCRIPTNAME}:INFO: The vlanid value is: ${vlanid}"
logger "${SCRIPTNAME}:INFO: The external network hint is: ${xtrnlhint}"
logger "${SCRIPTNAME}:INFO: The internal network hint is: ${ntrnlhint}"

exit 0

# export these.
export hostname
export wan1iface
export wan2iface
export laniface 
export portdata
export portcallp
export svctyp
export svcid
export vlanid
export xtrnlhint
export ntrnlhint

export bootstrapdsx_dsxnet
export bootstrapdsx_ifacectlplane
export bootstrapdsx_portreg
export bootstrapdsx_portra
export bootstrapdsx_svcgroup
export bootstrapdsx_svcgrptyp

# This function will take an IP and make sure that it is indeed a valid VNFC
# by checking to ensure it is set by the orchestrator in our environment
#
# returns 0 valid
# returns 1 invalid
# returns -1 error
function ipAssignedToVNFC
{
   local rc=1
   if [[ -z $1 ]]; then
      logger "${SCRIPTNAME}:ERROR: Argument Error. No parameter."
      rc=-1
   else
      IP=$1
      for LINE in `env`; do
         SRCH=`echo ${LINE} | grep ${IP}`
         if [ $? -eq 0 ]; then
            # logger "${SCRIPTNAME}.sh:DEBUG: Found IP ${IP} set to ${LINE}."
            NTWK=`echo ${SRCH} | cut -f 1 -d "="`
            if [ $? -eq 0 ]; then
               # logger "${SCRIPTNAME}.sh:DEBUG: IP assigned to VNFC ${NTWK}."
               rc=0
               echo ${NTWK}
            else
               logger "${SCRIPTNAME}.sh:WARN: Error parsing IP from env var."
               rc=-1
            fi
            break
         fi
      done
   fi

   if [[ $rc -eq 0 ]]; then
      return 0
   elif [[ $rc -eq 1 ]]; then
      return 1
   else
      return -1
   fi
   # should never reach here but is included to make sure we have a net
   return -1
}

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
      logger "${SCRIPTNAME}:ERROR: jsonParmSwap: No Python Version!"
      return 1
   else
      logger "${SCRIPTNAME}:INFO: jsonParmSwap: Python Version: ${pyver}"
   fi
      
   FILENAME=""
   FILECODE=""

   if [ -z "$1" -o -z "$2" ]; then
      logger "${SCRIPTNAME}:ERROR: jsonParmSwap: Argument Error: Required: FILECODE NEWIP"
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
      logger "${SCRIPTNAME}:ERROR: jsonParmSwap: Dir not found: ${DIRNAME}"
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
         logger "${SCRIPTNAME}:ERROR: jsonParmSwap: Invalid File Code."
         rm $parse_json_script
         popd
         return 1
      fi
         
      python $parse_json_script && rm $parse_json_script
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}:INFO: jsonParmSwap: Parm Replaced"
      else
         logger "${SCRIPTNAME}:ERROR: jsonParmSwap: Parm NOT Replaced"
         popd
         return 1
      fi   
   else
      logger "${SCRIPTNAME}: jsonParmSwap:ERROR: File Not Found:${FILENAME}"
      return 1
   fi
}

DVNELEMENT="vtc"

# Orchestrator does not pass the name into the env. But they DO use it in the hostname.
# We will take advantage of that.
HSTNM=`hostname | cut -f 1 -d "-"`
# In case they ever change this we need to be careful and check.
if [ $? -eq 0 ]; then
   if [[ ${HSTNM} == *"deflect"* ]]; then
      DVNELEMENT=deflect
   elif [[ ${HSTNM} == *"l3gw"* ]]; then
      DVNELEMENT=l3gw
   elif [[ ${HSTNM} == *"l3x"* ]]; then
      DVNELEMENT=l3x
   elif [[ ${HSTNM} == *"l2x"* ]]; then
      DVNELEMENT=l2x
   #elif [ ${ELEMENT} == "dvnclient" ]; then
   #   DVNELEMENT=${ELEMENT}
   else
      logger "${SCRIPTNAME}:ERROR: Unrecognized element."
      exit 1
   fi
fi
    
systemctl stop dvn.service

logger "${SCRIPTNAME}:INFO: Changing IP Address in CFG: ${bootstrapdsx_dsxnet}" 
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
   logger "${SCRIPTNAME}:WARN: No traffic interface specified on this instance (ifacetraffic)!" 
   logger "${SCRIPTNAME}:WARN: Attempting to locate an interface that can be used with defgw." 
   DFLTNIC=`ip -4 r ls | grep default | grep -Po '(?<=dev )(\S+)'`
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:WARN: Found default gw interface ${DFLTNIC}.Attempting to use that." 
      ifacetraffic=${DFLTNIC}
   else
      logger "${SCRIPTNAME}:ERROR: Unable to find an appropriate interface for DVN traffic." 
      exit 1 
   fi
else
   if [ ${ifacetraffic} == "lo" ]; then
      logger "${SCRIPTNAME}:ERROR: Invalid loopback interface specified in ifacetraffic." 
      exit 1 
   fi
fi

# Just because a variable says we should be using interface ethx does not mean it is so. Check it.
if [ ! -d "/sys/class/net/${ifacetraffic}" ]; then
   logger "${SCRIPTNAME}:ERROR: NIC ${ifacetraffic} not valid or enabled on this instance!" 
   exit 1
else
   logger "${SCRIPTNAME}:INFO: Changing nic in CFG: ${ifacetraffic}" 
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

# OpenBaton assigns every node a unique id and passes it into the environment.
#
# It uses this id to name the hosts. In fact, because it uses a hyphen as 
# part of the convention we had to disable the DNS prefix in OpenStack to keep
# things from blowing up.
#
# But we would rather not use this OpenBaton ID when provisioning things in DART
# because we would see these crazy numbers that do not mean anything. 
#
# I think a better id is to grab the IP of the node and use that instead. This
# means that we need to choose an IP that the DSX will also choose. 
MYIP="127.0.0.1"
VNFC="local"
# We may have multiple IPs on a given interface! So this needs to be a loop.
for IP in `ip -4 a show ${ifacetraffic} | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`; do
   # If we have multiple IPs on our WAN we will get really confused about our identity 
   # And it can if you are running VRRP or something like that. If we are running VRRP 
   # the virtual IP used for failover is almost always the subsequent address on the nic.
   # But we could get confused about who we are if we see multiple IPs on the interface.
   # So I think for now we will exit if we see this occur.
   if [ ${MYIP} == "127.0.0.1" ]; then
      MYIP=${IP}
   else
      logger "${SCRIPTNAME}:ERROR: Multiple IPs assigned to ${ifacetraffic}. Unexpected. Exiting." 
      exit 1
   fi

   VNFC=$(ipAssignedToVNFC ${IP})
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO: IP: ${IP} assigned to ${VNFC}."
      MYIP=${IP}
      break
   elif [ $? -eq 1 ]; then
      logger "${SCRIPTNAME}:DEBUG: IP: ${IP} NOT assigned to ${VNFC}."
   elif [ $? -eq -1 ]; then
      logger "${SCRIPTNAME}:ERROR: Error calling function ipAssignedToVNFC with arg: ${IP}."
      exit 1
   else
      logger "${SCRIPTNAME}:ERROR: Unexpected return code from ipAssignedToVNFC. Exiting."
      exit 1
   fi
done

NODENUM=`echo ${MYIP} | cut -f2-4 -d "." | sed 's+\.+x+'`
if [ $? -eq 0 ]; then
   export VTCNAME=OB${NODENUM}
else
   logger "${SCRIPTNAME}: Unable to determine NODENUM by IP Address." 
   exit 1
fi

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
   logger "Script: ${SCRIPTNAME}:WARN: dvn.service did not stop. non-fatal. We will continue."
else
   logger "Script: ${SCRIPTNAME}:INFO: dvn.service stopped."
fi

sleep 3

logger "Script: ${SCRIPTNAME}.sh:INFO: Restarting dvn.service after setting parameters."
systemctl restart dvn.service
OUTPUT=`systemctl is-active dvn.service`
if [ $? -eq 0 ]; then
   logger "Script: ${SCRIPTNAME}:INFO: dvn.service restarted."
else
   logger "Script: ${SCRIPTNAME}:ERROR: dvn.service did NOT restart. Manual intervention required."
   exit 1 
fi

#set +x
exit 0
