#!/bin/bash
#title           :l3gw_configure.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash l3gw_configure.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is called by any element specified to be dependent upon the l3gw 
#==============================================================================
#set -x

# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

SCRIPTNAME="l3gw_configure"
logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

SCRIPTDIR="/opt/openbaton/scripts"
if [ ! -d "${SCRIPTDIR}" ]; then
   logger "${SCRIPTNAME}:ERROR:Directory Not Found:${SCRIPTDIR}. Using ${PWD}".
   SCRIPTDIR=${PWD}
fi

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env.$$"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
# Print env out so we can see what is getting passed into us from orchestrator.
echo "====================================================" >> ${ENVFILE}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVFILE}
env >> ${ENVFILE}
echo "" >> ${ENVFILE}
echo "====================================================" >> ${ENVFILE}

logger "${SCRIPTNAME}:INFO: Greetings Bootstrap DSX! I am a Gateway."
logger "${SCRIPTNAME}:INFO: I see your IP Address is: ${dsxnet}"
logger "${SCRIPTNAME}:INFO: I see your hostname is: ${hostname}"
logger "${SCRIPTNAME}:INFO: I see your portreg is: ${portreg}"
logger "${SCRIPTNAME}:INFO: I see your portra is: ${portra}"

logger "${SCRIPTNAME}:INFO: Enough about you. Lets talk about ME!" 
logger "${SCRIPTNAME}:INFO: My hostname is: ${l3gw_hostname}" 
logger "${SCRIPTNAME}:INFO: I will be sending data on port: ${l3gw_portdata}" 
logger "${SCRIPTNAME}:INFO: I will be sending callp on port: ${l3gw_portcallp}" 
logger "${SCRIPTNAME}:INFO: My WAN 1 Interface is: ${l3gw_wan1iface}" 
logger "${SCRIPTNAME}:INFO: My WAN 2 Interface is: ${l3gw_wan2iface}" 
logger "${SCRIPTNAME}:INFO: My LAN Interface is: ${l3gw_laniface}" 
logger "${SCRIPTNAME}:INFO: My VLD Interface for external network is: ${l3gw_gw1vldext1}" 
logger "${SCRIPTNAME}:INFO: My VLD Interface for external network is: ${l3gw_gw2vldext1}" 
# Bug with using same var in both gateways
#logger "${SCRIPTNAME}:INFO: My VLD Interface for external network is: ${l3gw_vldext1}" 
logger "${SCRIPTNAME}:INFO: My VLD Interface for internal network is: ${l3gw_vldinternal}" 
logger "${SCRIPTNAME}:INFO: The Service Group I will attempt to use is: ${l3gw_svcgrp}" 
logger "${SCRIPTNAME}:INFO: The Service Type I will attempt to provision is: ${l3gw_svctyp}" 
logger "${SCRIPTNAME}:INFO: The Service ID I will attempt to provision is: ${l3gw_svcid}" 
logger "${SCRIPTNAME}:INFO: The VLAN Id I will attempt to provision is: ${l3gw_vlanid}" 
logger "${SCRIPTNAME}:INFO: The dvn identifier value is: ${l3gw_dvnidentifier}" 

# export the variables
#export dsxnet
#export hostname
#export ifacectlplane
#export l3gw_portdata
#export l3gw_portcallp
#export l3gw_wan1iface
#export l3gw_wan2iface
#export l3gw_laniface
#export l3gw_gw1vldext1
#export l3gw_gw2vldext1
#export l3gw_vldext1
#export l3gw_vldinternal
#export l3gw_svcgrp
#export l3gw_svctyp
#export l3gw_svcid
#export l3gw_vlanid
#export l3gw_dvnidentifier

# We will initialize the deflect IP to an anycast. 
# Maybe not the smartest idea but # we will make sure we check it.
L3GW_IP="0.0.0.0"

#
# As the orchestrator orchestrates scripts between VMs one of the challenges we face
# is that there is no smoking gun means of determining what the variable name is 
# so that we can find that element IP Address. This is because it is a concatenation
# of the name of the element and the network that is supplied in the descriptor.
# We can figure it out. But it takes a little smarts and processing to do so.
# 
# TODO: FOLLOWUP: If a deflect were to ever have more than one network specified in the
# descriptor we could actually have an issue with this strategy of IP determination.
# We might consider adopting the logic I put in place for the gateways which I knew
# going in would have multiple interfaces.
#
function valid_ip()
{
   local  IP=$1
   local  RC=1

   if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      # placehold the default IFS the system is using.
      OIFS=$IFS
      IFS='.'
      IP=($IP)
      # restore original system IFS.  
      IFS=$OIFS
      [[ ${IP[0]} -le 255 && ${IP[1]} -le 255 && ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
      rc=$?
   fi  
   return $rc 
}

# originally this would look for all VLD IP addresses.
# modified so that a specific VLD can be passed in which helps us avoid getting
# and setting the wrong IP address.
function findmyip()
{
   local rc=1
   L3GW_VARPREFIX=l3gw_

   logger "${SCRIPTNAME}:DEBUG: Function findmyip: arg: ${1}."
   SRCHSTR="${L3GW_VARPREFIX}$1"
   logger "${SCRIPTNAME}:DEBUG: SRCHSTR: ${SRCHSTR}."
   # grab all of the env var values related to the deflect element that orchestrator passes in.
   #for var in `env | grep -i "${L3GW_VARPREFIX}" | cut -f 2 -d "="`; do
   for var in `env | grep -i "${SRCHSTR}" | cut -f 2 -d "="`; do
      # one will be the IP Address. we need to figure out which. w
      # we would not know unless we knew what network was specified in the descriptor.
      if valid_ip ${var}; then
         echo ${var}
         rc=0
         break
      fi
   done
   return $rc
}

# we discovered in testing that the modified value of dvnidentified modified in INSTANTIATE script
# did not get passed in and we only got the original descriptor value. unless this is fixed by 
# open baton team we have to do something else.
#
#if valid_ip ${l3gw_dvnidentifier}; then
#  L3GW_IP=${l3gw_dvnidentifier}

# found another bug where this var was not getting set for each respective gateway for some
# reason. Hence the retry with second variable.
WAN1IP=$(findmyip ${l3gw_gw1vldext1})
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: IP Address located for the gw1vldext1 VLD ${l3gw_gw1vldext1}: ${WAN1IP}."
   # We probably need to consider using all octets if we are going to this.
else
   #logger "${SCRIPTNAME}:ERROR: Invalid IP Address on var dvnidentifier: ${l3gw_dvnidentifier}."
   logger "${SCRIPTNAME}:ERROR: No IP Address located for VLD: ${l3gw_gw1vldext1}."
   WAN1IP=$(findmyip ${l3gw_gw2vldext1})
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO: IP Address located for the gw1vldext1 VLD ${l3gw_gw2vldext1}: ${WAN1IP}."
   else
      logger "${SCRIPTNAME}:ERROR: No IP Address located for VLD: ${l3gw_gw2vldext1}."
      exit 1
   fi
fi

NODENUM=`echo ${WAN1IP} | cut -f3-4 -d "." | sed 's+\.+DT+'`
export VTCNAME=OPNBTN${NODENUM}

#if [ $? -eq 0 ]; then
#   logger "${SCRIPTNAME}:INFO: IP Address discovered as: ${L3GW_IP}."
#   NODENUM=`echo ${L3GW_IP} | cut -f3-4 -d "." | sed 's+\.+DT+'`
#   export VTCNAME=OPNBTN${NODENUM}
#else
#   logger "${SCRIPTNAME}:ERROR: IP Address NOT discovered: Still defaulted to: ${L3GW_IP}. Exiting."
#   exit 1
#fi

logger "${SCRIPTNAME}:INFO: Checking for Python3."
python3 -V
if [ $? -ne 0 ]; then
   logger "${SCRIPTNAME}:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

# Go ahead and make sure we have what we need to do the job
RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"
if [ ! -d ${RESTCLTDIR} ]; then
   logger "${SCRIPTNAME}:ERROR: DirNotExists: ${RSTCLTDIR}"
   exit 1
else
   pushd ${RESTCLTDIR}
   logger "${SCRIPTNAME}:INFO: Checking for REST API Client files."
   for filename in "rxtxnode.py" "callp.py" "deflect.py"; do
      if [ ! -f ${filename} ]; then
         logger "${SCRIPTNAME}:ERROR: FileNotExists: ${filename}"
         popd
         exit 1
      else
         # this is always an issue w scripts so just be proactive and fix it.
         if [ ! -x ${filename} ]; then
            chmod +x ${filename}
         fi 
      fi 
   done 
fi

DVNRESTENV=".dvnrestenv"
if [ -f ${DVNRESTENV} ]; then
   logger "${SCRIPTNAME}:INFO: Sourcing rest environment..."
   source "${DVNRESTENV}"
else
   logger "${SCRIPTNAME}:ERROR: FileNotFound: ${DVNRESTENV}"
   popd
   exit 1
fi

CLASSFILE=rxtxnode
logger "${SCRIPTNAME}:INFO: Attempting to provision new vtc ${VTCNAME}."
(python3 ${CLASSFILE}.py --operation provision --nodeid ${VTCNAME} --mnemonic ${VTCNAME} 1>${CLASSFILE}.py.log.$$ 2>&1)
if [ $? -eq 0 -o $? -eq 4 ]; then
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO: RxTxNode (VTC) ${VTCNAME} provisioned!"
   else     
       logger "${SCRIPTNAME}:WARN: RxTxNode ${VTCNAME} already provisioned (assumed correct)."
   fi

   # We could automagically drop a loopback service on a gateway. Not a bad idea.
   # TODO: Consider the notion. 
   logger "${SCRIPTNAME}:INFO: Checking for a service to provision."
   if [ -z "${l3gw_svctyp}" ]; then
      logger "${SCRIPTNAME}:INFO: No service type passed in. Therefore no service to provision."
   else
      logger "${SCRIPTNAME}:INFO: Found service type: ${l3gw_svctyp}. Looking for additional parms so we can provision it."
      if [ -z "{l3gw_svcid}" -o -z "${l3gw_vlanid}" ]; then
         logger "${SCRIPTNAME}:ERROR: Missing required parm: svcid ${l3gw_svcid} or vlanid ${l3gw_vlanid}."
         popd
         exit 1
      fi

      if [ ${l3gw_svctyp} == "L2G" -o ${l3gw_svctyp} == "L2X" ]; then
         logger "${SCRIPTNAME}:ERROR: Service Type ${l3gw_svctyp} not valid on an L3 Gateway."
         logger "${SCRIPTNAME}:ERROR: Cannot provision Service id: ${l3gw_svcid} on vtc ${VTCNAME} ."
         popd
         exit 1
      elif [ ${l3gw_svctyp} != "L3C" -a ${l3gw_svdtyp} != "L3G" ]; then
         logger "${SCRIPTNAME}:ERROR: Unknown Service Type: ${l3gw_svctyp}"
         logger "${SCRIPTNAME}:ERROR: Cannot provision Service id: ${l3gw_svcid} on vtc ${VTCNAME} ."
         popd
         exit 1
      else
         CLASSFILE=service
         SVCID="${l3gw_svcid}${NODENUM}"
         logger "${SCRIPTNAME}:INFO: Attempting to provision ${l3gw_svctyp} service with id: ${SVCID} on vtc ${VTCNAME} ."
         (python3 ${CLASSFILE}.py --operation provision --svcid ${SVCID} --svctyp ${l3gw_svctyp} --nodeid ${VTCNAME}  --vlanid ${l3gw_vlanid} 1>${CLASSFILE}.py.log.$$ 2>&1)
         if [ $? -ne 0 ]; then
            logger "${SCRIPTNAME}:ERROR: Error provisioning Service id: ${l3gw_svcid} on vtc ${VTCNAME} ."
            popd
            exit 1
         fi
         logger "${SCRIPTNAME}:INFO: Service id: ${l3gw_svcid} successfully provisioned on vtc ${VTCNAME} ."
      fi
   fi
else
   logger "${SCRIPTNAME}:ERROR: Error provisioning RxTxNode ${VTCNAME}." 
   popd
   exit 1
fi

logger "${SCRIPTNAME}:INFO: Successful implementation of ${SCRIPTNAME} script. Exiting 0."
exit 0
#set +x
