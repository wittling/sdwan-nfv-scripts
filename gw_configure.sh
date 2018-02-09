#!/bin/bash
#set -x

# It appears that this script gets cranked for every dependent element that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

if [ -n ${SCRIPTNAME} ]; then
   echo "SCRIPTNAME is: ${SCRIPTNAME}"
else
   SCRIPTNAME="gw_configure"
   echo "No scriptname set. Using default scriptname: ${SCRIPTNAME}"
fi

SCRIPTDIR="/opt/openbaton/scripts"
logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

# Print env out so we can see what is getting passed into us from orchestrator.
ENVOUT="/opt/openbaton/scripts/${SCRIPTNAME}.env"
echo "====================================================" >> ${ENVOUT}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVOUT}
env >> ${ENVOUT}
echo "" >> ${ENVOUT}
echo "====================================================" >> ${ENVOUT}

logger "${SCRIPTNAME}: Greetings Bootstrap DSX! I am a Gateway."
logger "${SCRIPTNAME}: I see your IP Address is: ${dsxnet}"
logger "${SCRIPTNAME}: I see your hostname is: ${hostname}"
logger "${SCRIPTNAME}: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "${SCRIPTNAME}: I will be sending data on port: ${gw_portdata}" 
logger "${SCRIPTNAME}: I will be sending callp on port: ${gw_portcallp}" 
logger "${SCRIPTNAME}: I will be using svc group: ${svcgroup}" 
logger "${SCRIPTNAME}: I will be using deflect pool id: ${poolid}" 
logger "${SCRIPTNAME}: My WAN 1 Interface is: ${wan1iface}" 
logger "${SCRIPTNAME}: My WAN 2 Interface is: ${wan2iface}" 
logger "${SCRIPTNAME}: My LAN Interface is: ${laniface}" 
logger "${SCRIPTNAME}: My VLD Interface for internal network is: ${vldinternal}" 
logger "${SCRIPTNAME}: The Service Type I will attempt to provision is: ${svctyp}" 
logger "${SCRIPTNAME}: The Service ID I will attempt to provision is: ${svcid}" 
logger "${SCRIPTNAME}: The VLAN Id I will attempt to provision is: ${vlanid}" 

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp
export svcgroup
export poolid
export wan1iface
export wan2iface
export laniface
export vldinternal
export svctyp
export svcid
export vlanid


# We should be passing in a var that tells us what interface to use as our traffic interface.
# If we do not get that, we could decide to die, or we could decide to be clever and use 
# the interface that is currently associated with the default route.
if [ -z "${wan1iface}" ]; then
   logger "${SCRIPTNAME}:WARN:No wan1iface specified on this instance (ifacetraffic)!"
   logger "${SCRIPTNAME}:WARN:Attempting to locate an interface that can be used with defgw."
   DFLTNIC=`ip -4 r ls | grep default | grep -Po '(?<=dev )(\S+)'`
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:WARN:Found default gw interface ${DFLTNIC}.Attempting to use that."
      wan1iface=${DFLTNIC}
   else
      logger "${SCRIPTNAME}:ERROR:Unable to find an appropriate interface for DVN
      traffic."
      exit 1
   fi
elif [ ${wan1iface} == "lo" ]; then
      logger "${SCRIPTNAME}:ERROR:Invalid loopback interface specified in wan1iface."
      exit 1
else
   logger "${SCRIPTNAME}:ERROR:No parameter wan1iface Found."
   exit 1
fi

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
for IP in `ip -4 a show ${wan1iface} | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`; do
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
   # This is a nested loop.  Need to break out fully if we found it.
   if [ ${NTWK} != "local" ]; then
      break
   fi  
done

# OpenBaton likes to name the hosts with an appended hyphen and generated uid of some sort
# Not sure if rest likes hyphens so we will grab the suffix id and use that for provisioning. 
NODENUM=`echo ${wan1iface} | cut -f3-4 -d "." | sed 's+\.+DT+'`
export VTCNAME=OPNBTN${NODENUM}

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
logger "${SCRIPTNAME}: INFO: Attempting to provision new vtc ${hostname}."
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
   if [ -z "${svctyp}" ]; then
      logger "${SCRIPTNAME}: INFO: No service type passed in. Therefore no service to provision."
   else
      logger "${SCRIPTNAME}: INFO: Found service type: ${svctyp}. Looking for additional parms so we can provision it."
      if [ -z "{svcid}" -o -z "${vlanid}" ]; then
         logger "${SCRIPTNAME}: ERROR: Missing required parm: svcid ${svcid} or vlanid ${vlanid}."
         popd
         exit 1
      else
         if [ ${svctyp} == "L3C" -o \
              ${svctyp} == "L3G" -o \
              ${svctyp} == "L2G" -o \
              ${svdtyp} == "L2X" ]; then
            CLASSFILE=service
            logger "${SCRIPTNAME}: INFO: Attempting to provision ${svctyp} service with id: ${svcid} on vtc ${VTCNAME} ."
            (python3 ${CLASSFILE}.py --operation provision --svcid ${svcid} --mnemonic ${VTCNAME} 1>${CLASSFILE}.py.log.$$ 2>&1)
            if [ -? -eq 0 ]; then
               logger "${SCRIPTNAME}: INFO: Service id: ${svcid} successfully provisioned on vtc ${VTCNAME} ."
            else
               logger "${SCRIPTNAME}: ERROR: Error provisioning Service id: ${svcid} on vtc ${VTCNAME} ."
               popd
               exit 1
            fi
         else
            logger "${SCRIPTNAME}: ERROR: Unknown Service Type: ${svctyp}"
            logger "${SCRIPTNAME}: ERROR: Cannot provision Service id: ${svcid} on vtc ${VTCNAME} ."
            popd
            exit 1
         fi
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
