#!/bin/bash
#title           :deflect_configure.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash deflect_configure.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is called on the bootstrapdsx for every deflect that comes
# up with a VNFM dependency between the deflect and bootstrapdsx.
#==============================================================================
#env
#set -x
SCRIPTNAME="deflect_configure"
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


# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

logger "${SCRIPTNAME}: Greetings Bootstrap DSX! I am a Deflect."
logger "${SCRIPTNAME}: My Deflect IP Address is: ${deflect_dflnet}" 
logger "${SCRIPTNAME}: I see your IP Address is: ${dsxnet}"
logger "${SCRIPTNAME}: I see your hostname is: ${hostname}"
logger "${SCRIPTNAME}: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "${SCRIPTNAME}: I will be sending data on port: ${deflect_portdata}" 
logger "${SCRIPTNAME}: I will be sending callp on port: ${deflect_portcallp}" 
logger "${SCRIPTNAME}: I will be using svc group: ${svcgroup}" 
logger "${SCRIPTNAME}: I will be using deflect pool: ${poolid}" 

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp
export svcgroup
export poolid

# We will initialize the deflect IP to an anycast. 
# Maybe not the smartest idea but # we will make sure we check it.
DFL_IP="0.0.0.0"

#
# As the orchestrator orchestrates scripts between VMs one of the challenges we face
# is that there is no smoking gun means of determining what the variable name is 
# so that we can find that element IP Address. This is because it is a concatenation
# of the name of the element and the network that is supplied in the descriptor.
# 
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
   logger "${SCRIPTNAME}:INFO: IP Address discovered as: ${DFL_IP}."
   NODENUM=`echo ${DFL_IP} | cut -f1-4 -d "." | sed 's+\.+x+g'`
   export VTCNAME=OB${NODENUM}
else
   logger "${SCRIPTNAME}:ERROR: Unable to determine NODENUM based on IP. Exiting."
   exit 1
fi

logger "${SCRIPTNAME}:INFO: Checking for Python3."
python3 -V
if [ $? -ne 0 ]; then
   logger "${SCRIPTNAME}:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

# Go ahead and make sure we have what we need to do the job
logger "${SCRIPTNAME}:INFO: Checking for rest client directory: ${RESTCLTDIR}."
RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"
if [ ! -d ${RESTCLTDIR} ]; then
   logger "${SCRIPTNAME}:ERROR: DirNotExists: ${RSTCLTDIR}"
   exit 1
else
   pushd ${RESTCLTDIR}
   logger "${SCRIPTNAME}:INFO: Checking for REST API client classes we need."
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

logger "${SCRIPTNAME}:INFO: Checking for environment file ${DVNRESTENV}."
DVNRESTENV=".dvnrestenv"
if [ -f ${DVNRESTENV} ]; then
   logger "${SCRIPTNAME}:INFO: Sourcing rest environment..."
   source "${DVNRESTENV}"
else
   logger "${SCRIPTNAME}:ERROR: File Not Found: ${DVNRESTENV}."
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
       logger "${SCRIPTNAME}:WARN: RxTxNode (VTC) ${VTCNAME} already provisioned (assumed correct)."
   fi

   # Currently every node instantiated by the orchestrator is getting a CALLP and a Deflect.
   # We need a way to dynamically cap the CallP so that as the element is instantiated, if the
   # number of CallPs (max) has been hit, it holds off. The best way to do this is probably to 
   # make a REST call and not provision the CallP if the max number has been reached.
   # This is a TODO.
   CALLPNAME=CP${NODENUM}
   CLASSFILE=callp
   if [ -n "${deflect_portcallp}" ]; then
      logger "${SCRIPTNAME}: INFO: CallP Port ${deflect_portcallp}."
   else
      # use a default port
      deflect_portcallp=5535
      logger "${SCRIPTNAME}: WARN: No CallP Port variable supplied. Using:${deflect_portcallp}."
   fi
   logger "${SCRIPTNAME}: INFO: Attempting to provision new callp deflect ${CALLPNAME}."
   (python3 ${CLASSFILE}.py --operation provision --callpid ${CALLPNAME} --nodeid ${VTCNAME} --ipaddr ${deflect_dflnet} --port ${deflect_portcallp} --proto "udp" --addrtyp "Static" 1>${CLASSFILE}.py.log.$$ 2>&1)
   if [ $? -eq 0 -o $? -eq 4 ]; then
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}:INFO: CallP ${CALLPNAME} provisioned successfully."
      else     
       logger "${SCRIPTNAME}:WARN: CallP ${CALLPNAME} already provisioned (assumed correct)."
      fi

      if [ -n "${deflect_portdata}" ]; then
         logger "${SCRIPTNAME}: INFO: Data Deflect Port ${deflect_portdata}."
      else
         # use a default
         deflect_portdata=5525
         logger "${SCRIPTNAME}: WARN: No Data Deflect Port variable supplied. Using:${deflect_portdata}."
      fi
      DFLNAME=DFL${NODENUM}
      CLASSFILE=deflect
      logger "${SCRIPTNAME}: INFO: Attempting to provision new data deflect ${DFLNAME}."
      # This will not only provision the deflect but it will add it to the deflect pool, so no separate call needed.
      (python3 ${CLASSFILE}.py --operation provision --dflid ${DFLNAME} --mnemonic ${DFLNAME} --nodeid ${VTCNAME} --port ${deflect_portdata} --channeltype "udp" 1>${CLASSFILE}.py.log.$$ 2>&1)
      if [ $? -eq 0 -o $? -eq 4 ]; then
         if [ $? -eq 0 ]; then
            logger "${SCRIPTNAME}:INFO: Data Deflect ${DFLNAME} provisioned successfully."
         else
            logger "${SCRIPTNAME}:WARN: Data Deflect ${DFLNAME} already provisioned (assumed correct)."
         fi 

         # Assign to deflect pool.
         # We should be passing the pool id in from orchestrator. If not we can look and use service group.
         # If neither of those are set we will use a default. 
         if [ -n "${poolid}" ]; then
            logger "${SCRIPTNAME}: ERROR: Attempting to assign ${DFLNAME} to ${poolid}."
         else
            logger "${SCRIPTNAME}: ERROR: No valid poolid parameter."
            popd
            exit 1
         fi
         (python3 ${CLASSFILE}.py --operation poolassign --dflid ${DFLNAME} --poolid ${poolid} 1>${CLASSFILE}.py.log.$$ 2>&1)
         if [ $? -eq 0 ]; then 
            logger "${SCRIPTNAME}:INFO: Data Deflect ${DFLNAME} assigned to ${poolid}. Code $?."
         else
            logger "${SCRIPTNAME}:ERROR: Unable to assign Data Deflect ${DFLNAME} to ${poolid}. Code $?."
            popd
            exit 1
         fi
      else
         logger "${SCRIPTNAME}:ERROR: Unable to provision CallP Deflect ${CALLPNAME}. Code $?."
         # TODO: We could implement a transactional rollback attempt. Look into.
         popd
         exit 1
      fi
   else
      logger "${SCRIPTNAME}:ERROR: Unable to provision RxTxNode (VTC) ${VTCNAME}. Code $?."
      # TODO: We could implement a transactional rollback attempt. Look into.
      popd
      exit 1
   fi

   # It could be more efficient for the DSX to just make a single call and adjust the pool parms
   # after all deflects have come up. The DSX would need to have a count of them, which it
   # currently does not have. 
   # TODO: Look into making one DSX adjustment at the START event as opposed to using the 
   # CONFIGURE event for setting such parameters.
   CLASSFILE=deflectpool
   if [ -f ${CLASSFILE}.py ]; then
      # The provisioning up above has logic to put the deflect in the OPENBATON deflect pool. We will use a var.
      DFLPOOL=OPENBATON

      logger "${SCRIPTNAME}: INFO: Attempting to adjust deflect pool size."
      # This will not only provision the deflect but it will add it to the deflect pool, so no separate call needed.
      (python3 ${CLASSFILE}.py --operation autoadjchan --poolid ${DFLPOOL} 1>${CLASSFILE}.py.log 2>&1)
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}:INFO: Deflect Pool ${DFLPOOL} successfully adjusted with new vtc count."
      else
         logger "${SCRIPTNAME}:WARN: Unable to adjust deflect pool size for pool ${DFLPOOL}. Code $?."
      fi
   fi
fi

logger "${SCRIPTNAME}:INFO: Successful implementation of ${SCRIPTNAME} script. Exiting 0."
exit 0
#set +x
