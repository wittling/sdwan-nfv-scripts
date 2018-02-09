#!/bin/bash
#set -x

# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

SCRIPTNAME="l3gw_configure"
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

logger "${SCRIPTNAME}: Greetings Bootstrap DSX! I am a Gateway."
logger "${SCRIPTNAME}: I see your IP Address is: ${dsxnet}"
logger "${SCRIPTNAME}: I see your hostname is: ${hostname}"
logger "${SCRIPTNAME}: It appears you will be using the ctl plane interface: ${ifacectlplane}" 

logger "${SCRIPTNAME}: Enough about you. Lets talk about ME!" 
logger "${SCRIPTNAME}: I will be sending data on port: ${l3gw_portdata}" 
logger "${SCRIPTNAME}: I will be sending callp on port: ${l3gw_portcallp}" 
logger "${SCRIPTNAME}: I will be using svc group: ${l3gw_svcgroup}" 
logger "${SCRIPTNAME}: I will be using deflect pool id: ${l3gw_poolid}" 
logger "${SCRIPTNAME}: My WAN 1 Interface is: ${l3gw_wan1iface}" 
logger "${SCRIPTNAME}: My WAN 2 Interface is: ${l3gw_wan2iface}" 
logger "${SCRIPTNAME}: My LAN Interface is: ${l3gw_laniface}" 
logger "${SCRIPTNAME}: My VLD Interface for internal network is: ${l3gw_vldinternal}" 
logger "${SCRIPTNAME}: The Service Type I will attempt to provision is: ${l3gw_svctyp}" 
logger "${SCRIPTNAME}: The Service ID I will attempt to provision is: ${l3gw_svcid}" 
logger "${SCRIPTNAME}: The VLAN Id I will attempt to provision is: ${l3gw_vlanid}" 

# export the variables
export dsxnet
export hostname
export ifacectlplane
export l3gw_portdata
export l3gw_portcallp
export l3gw_svcgroup
export l3gw_poolid
export l3gw_wan1iface
export l3gw_wan2iface
export l3gw_laniface
export l3gw_vldinternal
export l3gw_svctyp
export l3gw_svcid
export l3gw_vlanid

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
   for var in `env | grep -i deflect | cut -f 2 -d "="`; do
      # one will be the IP Address. we need to figure out which. w
      # we would not know unless we knew what network was specified in the descriptor.
      if valid_ip ${var}; then
         DFL_IP=${var}
         rc=0
         break
      fi
   done
   return $rc
}

findmyip
if [ $? -eq 0 ]; then
   logger "deflect_configure:INFO: IP Address discovered as: ${L3GW_IP}."
   NODENUM=`echo ${L3GW_IP} | cut -f3-4 -d "." | sed 's+\.+DT+'`
   export VTCNAME=OPNBTN${NODENUM}
else
   logger "deflect_configure:ERROR: IP Address NOT discovered: Still defaulted to: ${L3GW_IP}. Exiting."
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
logger "${SCRIPTNAME}: INFO: Attempting to provision new vtc ${VTCNAME}."
(python3 ${CLASSFILE}.py --operation provision --nodeid ${VTCNAME} --mnemonic ${VTCNAME} 1>${CLASSFILE}.py.log.$$ 2>&1)
if [ $? -eq 0 -o $? -eq 4 ]; then
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO: RxTxNode (VTC) ${VTCNAME} provisioned!"
   else     
       logger "${SCRIPTNAME}:WARN: RxTxNode ${VTCNAME} already provisioned (assumed correct)."
   fi

   # We could automagically drop a loopback service on a gateway. Not a bad idea.
   # TODO: Consider the notion. 
   logger "${SCRIPTNAME}: INFO: Checking for a service to provision."
   if [ -z "${l3gw_svctyp}" ]; then
      logger "${SCRIPTNAME}: INFO: No service type passed in. Therefore no service to provision."
   else
      logger "${SCRIPTNAME}: INFO: Found service type: ${l3gw_svctyp}. Looking for additional parms so we can provision it."
      if [ -z "{l3gw_svcid}" -o -z "${l3gw_vlanid}" ]; then
         logger "${SCRIPTNAME}: ERROR: Missing required parm: svcid ${l3gw_svcid} or vlanid ${l3gw_vlanid}."
         popd
         exit 1
      fi

      if [ ${l3gw_svctyp} != "L3C" -a \
           ${l3gw_svctyp} != "L3G" -a \
           ${l3gw_svctyp} != "L2G" -a \
           ${l3gw_svdtyp} != "L2X" ]; then
         logger "${SCRIPTNAME}: ERROR: Unknown Service Type: ${l3gw_svctyp}"
         logger "${SCRIPTNAME}: ERROR: Cannot provision Service id: ${l3gw_svcid} on vtc ${VTCNAME} ."
         popd
         exit 1
      else
         CLASSFILE=service
         logger "${SCRIPTNAME}: INFO: Attempting to provision ${l3gw_svctyp} service with id: ${l3gw_svcid} on vtc ${VTCNAME} ."
         (python3 ${CLASSFILE}.py --operation provision --svcid ${l3gw_svcid} --mnemonic ${VTCNAME} 1>${CLASSFILE}.py.log.$$ 2>&1)
         if [ -? -ne 0 ]; then
            logger "${SCRIPTNAME}: ERROR: Error provisioning Service id: ${l3gw_svcid} on vtc ${VTCNAME} ."
            popd
            exit 1
         fi
         logger "${SCRIPTNAME}: INFO: Service id: ${l3gw_svcid} successfully provisioned on vtc ${VTCNAME} ."
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
