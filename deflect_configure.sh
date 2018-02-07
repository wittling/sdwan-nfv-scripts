#!/bin/bash
#set -x

# Print env out so we can see what is getting passed into us from orchestrator.
ENVOUT="/opt/openbaton/scripts/deflect_configure.env"
echo "====================================================" >> ${ENVOUT}
echo "Environment relevant to deflect_configure.sh script: " >> ${ENVOUT}
env >> ${ENVOUT}
echo "" >> ${ENVOUT}
echo "====================================================" >> ${ENVOUT}

# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

logger "deflect_configure: Greetings Bootstrap DSX! I am a Deflect."
logger "deflect_configure: My Deflect IP Address is: ${deflect_dflnet}" 
logger "deflect_configure: I see your IP Address is: ${dsxnet}"
logger "deflect_configure: I see your hostname is: ${hostname}"
logger "deflect_configure: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "deflect_configure: I will be sending data on port: ${deflect_portdata}" 
logger "deflect_configure: I will be sending callp on port: ${deflect_portcallp}" 
logger "deflect_configure: I will be using svc group: ${svcgroup}" 
logger "deflect_configure: I will be using deflect pool: ${poolid}" 

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp
export svcgroup
export poolid

# OpenBaton likes to name the hosts with an appended hyphen and generated uid of some sort
# Not sure if rest likes hyphens so we will grab the suffix id and use that for provisioning. 
if [ -n "${deflect_dflnet}" ]; then
   NODENUM=`echo ${deflect_dflnet} | cut -f3-4 -d "." | sed 's+\.+DT+'`
   export VTCNAME=OPNBTN${NODENUM}
else
   logger "deflect_configure:ERROR: No IP Address to set VTCName."
   exit 1
fi

logger "deflect_configure:INFO: Checking for Python3."
python3 -V
if [ $? -ne 0 ]; then
   logger "deflect_configure:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

# Go ahead and make sure we have what we need to do the job
logger "deflect_configure:INFO: Checking for rest client directory: ${RESTCLTDIR}."
RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"
if [ ! -d ${RESTCLTDIR} ]; then
   logger "deflect_configure:ERROR: DirNotExists: ${RSTCLTDIR}"
   exit 1
else
   pushd ${RESTCLTDIR}
   logger "deflect_configure:INFO: Checking for REST API client classes we need."
   for filename in "rxtxnode.py" "callp.py" "deflect.py"; do
      if [ ! -f ${filename} ]; then
         logger "deflect_configure:ERROR: FileNotExists: ${filename}"
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

logger "deflect_configure:INFO: Checking for environment file ${DVNRESTENV}."
DVNRESTENV=".dvnrestenv"
if [ -f ${DVNRESTENV} ]; then
   logger "deflect_configure:INFO: Sourcing rest environment..."
   source "${DVNRESTENV}"
else
   logger "deflect_configure:ERROR: File Not Found: ${DVNRESTENV}."
   popd
   exit 1
fi

CLASSFILE=rxtxnode
logger "deflect_configure: INFO: Attempting to provision new vtc ${VTCNAME}."
(python3 ${CLASSFILE}.py --operation provision --nodeid ${VTCNAME} --mnemonic ${VTCNAME} 1>${CLASSFILE}.py.log.$$ 2>&1)
if [ $? -eq 0 -o $? -eq 4 ]; then
   if [ $? -eq 0 ]; then
      logger "deflect_configure:INFO: RxTxNode (VTC) ${VTCNAME} provisioned!"
   else     
       logger "deflect_configure:WARN: RxTxNode (VTC) ${VTCNAME} already provisioned (assumed correct)."
   fi

   # Currently every node instantiated by the orchestrator is getting a CALLP and a Deflect.
   # We need a way to dynamically cap the CallP so that as the element is instantiated, if the
   # number of CallPs (max) has been hit, it holds off. The best way to do this is probably to 
   # make a REST call and not provision the CallP if the max number has been reached.
   # This is a TODO.
   CALLPNAME=CP${NODENUM}
   CLASSFILE=callp
   if [ -n "${deflect_portcallp}" ]; then
      logger "deflect_configure: INFO: CallP Port ${deflect_portcallp}."
   else
      # use a default port
      deflect_portcallp=5535
      logger "deflect_configure: WARN: No CallP Port variable supplied. Using:${deflect_portcallp}."
   fi
   logger "deflect_configure: INFO: Attempting to provision new callp deflect ${CALLPNAME}."
   (python3 ${CLASSFILE}.py --operation provision --callpid ${CALLPNAME} --nodeid ${VTCNAME} --ipaddr ${deflect_dflnet} --port ${deflect_portcallp} --proto "udp" --addrtyp "Static" 1>${CLASSFILE}.py.log.$$ 2>&1)
   if [ $? -eq 0 -o $? -eq 4 ]; then
      if [ $? -eq 0 ]; then
         logger "deflect_configure:INFO: CallP ${CALLPNAME} provisioned successfully."
      else     
       logger "deflect_configure:WARN: CallP ${CALLPNAME} already provisioned (assumed correct)."
      fi

      if [ -n "${deflect_portdata}" ]; then
         logger "deflect_configure: INFO: Data Deflect Port ${deflect_portdata}."
      else
         # use a default
         deflect_portdata=5525
         logger "deflect_configure: WARN: No Data Deflect Port variable supplied. Using:${deflect_portdata}."
      fi
      DFLNAME=DFL${NODENUM}
      CLASSFILE=deflect
      logger "deflect_configure: INFO: Attempting to provision new data deflect ${DFLNAME}."
      # This will not only provision the deflect but it will add it to the deflect pool, so no separate call needed.
      (python3 ${CLASSFILE}.py --operation provision --dflid ${DFLNAME} --mnemonic ${DFLNAME} --nodeid ${VTCNAME} --port ${deflect_portdata} --channeltype "udp" 1>${CLASSFILE}.py.log.$$ 2>&1)
      if [ $? -eq 0 -o $? -eq 4 ]; then
         if [ $? -eq 0 ]; then
            logger "deflect_configure:INFO: Data Deflect ${DFLNAME} provisioned successfully."
         else
            logger "deflect_configure:WARN: Data Deflect ${DFLNAME} already provisioned (assumed correct)."
         fi 

         # Assign to deflect pool.
         # We should be passing the pool id in from orchestrator. If not we can look and use service group.
         # If neither of those are set we will use a default. 
         if [ -n "${poolid}" ]; then
            logger "deflect_configure: ERROR: Attempting to assign ${DFLNAME} to ${poolid}."
         else
            logger "deflect_configure: ERROR: No valid poolid parameter."
            popd
            exit 1
         fi
         (python3 ${CLASSFILE}.py --operation poolassign --dflid ${DFLNAME} --poolid ${poolid} 1>${CLASSFILE}.py.log.$$ 2>&1)
         if [ $? -eq 0 ]; then 
            logger "deflect_configure:INFO: Data Deflect ${DFLNAME} assigned to ${poolid}. Code $?."
         else
            logger "deflect_configure:ERROR: Unable to assign Data Deflect ${DFLNAME} to ${poolid}. Code $?."
            popd
            exit 1
         fi
      else
         logger "deflect_configure:ERROR: Unable to provision CallP Deflect ${CALLPNAME}. Code $?."
         # TODO: We could implement a transactional rollback attempt. Look into.
         popd
         exit 1
      fi
   else
      logger "deflect_configure:ERROR: Unable to provision RxTxNode (VTC) ${VTCNAME}. Code $?."
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

      logger "deflect_configure: INFO: Attempting to adjust deflect pool size."
      # This will not only provision the deflect but it will add it to the deflect pool, so no separate call needed.
      (python3 ${CLASSFILE}.py --operation autoadjchan --poolid ${DFLPOOL} 1>${CLASSFILE}.py.log 2>&1)
      if [ $? -eq 0 ]; then
         logger "deflect_configure:INFO: Deflect Pool ${DFLPOOL} successfully adjusted with new vtc count."
      else
         logger "deflect_configure:WARN: Unable to adjust deflect pool size for pool ${DFLPOOL}. Code $?."
      fi
   fi
fi

logger "deflect_configure:INFO: Successful implementation of deflect_configure script. Exiting 0."
exit 0
#set +x
