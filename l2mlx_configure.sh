#!/bin/bash
#title           :l2mlx_configure.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash l2mlx_configure.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is called by any element specified to be dependent upon the l2mlx 
#==============================================================================
#set -x

# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

SCRIPTNAME="l2mlx_configure"
SCRIPTDIR="/opt/openbaton/scripts"

if [ ! -d "${SCRIPTDIR}" ]; then
   logger "${SCRIPTNAME}:ERROR:Directory Not Found:${SCRIPTDIR}" 
   exit 1
fi

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
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
logger "${SCRIPTNAME}:INFO: It appears you will be using the ctl plane interface: ${ifacectlplane}" 

logger "${SCRIPTNAME}:INFO: Enough about you. Lets talk about ME!" 
logger "${SCRIPTNAME}:INFO: I will be sending data on port: ${l2mlx_portdata}" 
logger "${SCRIPTNAME}:INFO: I will be sending callp on port: ${l2mlx_portcallp}" 
logger "${SCRIPTNAME}:INFO: My WAN 1 Interface is: ${l2mlx_wan1iface}" 
logger "${SCRIPTNAME}:INFO: My WAN 2 Interface is: ${l2mlx_wan2iface}" 
logger "${SCRIPTNAME}:INFO: My LAN Interface is: ${l2mlx_laniface}" 
logger "${SCRIPTNAME}:INFO: My VLD Interface for internal network is: ${l2mlx_vldinternal}" 
logger "${SCRIPTNAME}:INFO: The Service Group I will attempt to use is: ${l2mlx_svcgrp}" 
logger "${SCRIPTNAME}:INFO: The Service Type I will attempt to provision is: ${l2mlx_svctyp}" 
logger "${SCRIPTNAME}:INFO: The Service ID I will attempt to provision is: ${l2mlx_svcid}" 
logger "${SCRIPTNAME}:INFO: The VLAN Id I will attempt to provision is: ${l2mlx_vlanid}" 

L3GW_VARPREFIX=l2mlx_

# export the variables
export dsxnet
export hostname
export ifacectlplane
export l2mlx_portdata
export l2mlx_portcallp
export l2mlx_wan1iface
export l2mlx_wan2iface
export l2mlx_laniface
export l2mlx_vldinternal
export l2mlx_svcgrp
export l2mlx_svctyp
export l2mlx_svcid
export l2mlx_vlanid

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

function findmyip()
{
   local rc=1
   # grab all of the env var values related to the deflect element that orchestrator passes in.
   for var in `env | grep -i "${L3GW_VARPREFIX}" | cut -f 2 -d "="`; do
      # one will be the IP Address. we need to figure out which. w
      # we would not know unless we knew what network was specified in the descriptor.
      if valid_ip ${var}; then
         L3GW_IP=${var}
         rc=0
         break
      fi
   done
   return $rc
}

findmyip
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: IP Address discovered as: ${L3GW_IP}."
   NODENUM=`echo ${L3GW_IP} | cut -f3-4 -d "." | sed 's+\.+DT+'`
   export VTCNAME=OPNBTN${NODENUM}
else
   logger "${SCRIPTNAME}:ERROR: IP Address NOT discovered: Still defaulted to: ${L3GW_IP}. Exiting."
   exit 1
fi

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
   if [ -z "${l2mlx_svctyp}" ]; then
      logger "${SCRIPTNAME}:INFO: No service type passed in. Therefore no service to provision."
   else
      logger "${SCRIPTNAME}:INFO: Found service type: ${l2mlx_svctyp}. Looking for additional parms so we can provision it."
      if [ -z "{l2mlx_svcid}" -o -z "${l2mlx_vlanid}" ]; then
         logger "${SCRIPTNAME}:ERROR: Missing required parm: svcid ${l2mlx_svcid} or vlanid ${l2mlx_vlanid}."
         popd
         exit 1
      fi

      if [ ${l2mlx_svctyp} == "L2G" -o ${l2mlx_svctyp} == "L2X" ]; then
         logger "${SCRIPTNAME}:ERROR: Service Type ${l2mlx_svctyp} not valid on an L3 Gateway."
         logger "${SCRIPTNAME}:ERROR: Cannot provision Service id: ${l2mlx_svcid} on vtc ${VTCNAME} ."
         popd
         exit 1
      elif [ ${l2mlx_svctyp} != "L3C" -a ${l2mlx_svdtyp} != "L3G" ]; then
         logger "${SCRIPTNAME}:ERROR: Unknown Service Type: ${l2mlx_svctyp}"
         logger "${SCRIPTNAME}:ERROR: Cannot provision Service id: ${l2mlx_svcid} on vtc ${VTCNAME} ."
         popd
         exit 1
      else
         CLASSFILE=service
         logger "${SCRIPTNAME}:INFO: Attempting to provision ${l2mlx_svctyp} service with id: ${l2mlx_svcid} on vtc ${VTCNAME} ."
         (python3 ${CLASSFILE}.py --operation provision --svcid ${l2mlx_svcid} --svctyp ${l2mlx_svctyp} --nodeid ${VTCNAME}  --vlanid ${l2mlx_vlanid} 1>${CLASSFILE}.py.log.$$ 2>&1)
         if [ $? -ne 0 ]; then
            logger "${SCRIPTNAME}:ERROR: Error provisioning Service id: ${l2mlx_svcid} on vtc ${VTCNAME} ."
            popd
            exit 1
         fi
         logger "${SCRIPTNAME}:INFO: Service id: ${l2mlx_svcid} successfully provisioned on vtc ${VTCNAME} ."
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
