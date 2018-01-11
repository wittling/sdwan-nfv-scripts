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
logger "deflect_configure: I will be using svc group and deflect pool: ${svcgroup}" 

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp
export svcgroup

# OpenBaton likes to name the hosts with an appended hyphen and generated uid of some sort
# Not sure if rest likes hyphens so we will grab the suffix id and use that for provisioning. 
NODENUM=`echo ${deflect_dflnet} | cut -f 4 -d "."`
export VTCNAME=OPNBTN${NODENUM}

logger "deflect_configure:INFO: Attempting to provision VTC via REST interface"
python3 -V
if [ $? -eq 0 ]; then
   RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"
   if [ -d ${RESTCLTDIR} ]; then
      pushd ${RESTCLTDIR}
      CLASSFILE=rxtxnode
      if [ -f ${CLASSFILE}.py ]; then
         if [ ! -x ${CLASSFILE}.py ]; then
            chmod +x ${CLASSFILE}.py
         fi
         DVNRESTENV=".dvnrestenv"
         if [ -f ${DVNRESTENV} ]; then
            logger "deflect_configure:INFO: Sourcing rest environment..."
            source "${DVNRESTENV}"
         else
            logger "deflect_configure:INFO: Sourcing rest environment..."
            popd
            exit 1
         fi

         logger "deflect_configure: INFO: Attempting to provision new vtc ${hostname}."
         (python3 ${CLASSFILE}.py ${VTCNAME} ${VTCNAME} "no" 1>${CLASSFILE}.py.log 2>&1)
         if [ $? -eq 0 ]; then
            logger "deflect_configure:INFO: VTC ${VTCNAME} provisioned!"
            logger "deflect_configure:INFO: Provisioning ${VTCNAME} as Deflect."
            CLASSFILE=callp
            if [ -f ${CLASSFILE}.py ]; then
               if [ ! -x ${CLASSFILE}.py ]; then
                  chmod +x ${CLASSFILE}.py
               fi

               # Currently every node instantiated by the orchestrator is getting a CALLP and a Deflect.
               # We need a way to dynamically cap the CallP so that as the element is instantiated, if the
               # number of CallPs (max) has been hit, it holds off. The best way to do this is probably to 
               # make a REST call and not provision the CallP if the max number has been reached.
               # This is a TODO.
               CALLPNAME=CP${NODENUM}
               logger "deflect_configure: INFO: Attempting to provision new callp deflect ${CALLPNAME}."

               (python3 ${CLASSFILE}.py ${CALLPNAME} ${VTCNAME} ${deflect_dflnet} ${deflect_portcallp} "udp" "Static" 1>${CLASSFILE}.py.log 2>&1)
               if [ $? -eq 0 ]; then
                  logger "deflect_configure:INFO: CallP ${CALLPNAME} provisioned successfully."
               elif [ $? -eq 4 ]; then
                  logger "deflect_configure:INFO: CallP ${CALLPNAME} already provisioned (assumed correct)."
               else
                  logger "deflect_configure:ERROR: Unable to provision CallP ${CALLPNAME}. Code $?."
                  popd
                  exit 1
               fi

               CLASSFILE=deflect
               DFLNAME=DFL${NODENUM}
               logger "deflect_configure: INFO: Attempting to provision new data deflect ${DFLNAME}."
               # This will not only provision the deflect but it will add it to the deflect pool, so no separate call needed.
               (python3 ${CLASSFILE}.py ${DFLNAME} ${DFLNAME} ${VTCNAME} ${deflect_portdata} "udp" ${svcgroup} 1>${CLASSFILE}.py.log 2>&1)
               if [ $? -eq 0 ]; then
                  logger "deflect_configure:INFO: Data Deflect ${DFLNAME} provisioned successfully."
               elif [ $? -eq 4 ]; then
                  logger "deflect_configure:INFO: Data Deflect ${DFLNAME} already provisioned (assumed correct)."
               else
                  logger "deflect_configure:ERROR: Unable to provision Data Deflect ${DFLNAME}. Code $?."
                  popd
                  exit 1
               fi

               # It would be more efficient to make one call and adjust the pool size after deflects 
               # come up. But because of the various engines like scaling, we probably need to adjust
               # the pool every time a scaling event happens. Last time I tried to put a scale event
               # script in the descriptor, it did not fire. So for now at least, we will adjust the 
               # pool size here because we know this script gets triggered every time a deflect comes up.
               #
               # TODO: This could cause an issue on downward retraction of elasticity because our target
               # min max band may be higher than the actual deflects that are currently in use.
               #
               # We eventually need to make sure we can adjust the pool size based on scaling events.
               CLASSFILE=deflectpool
               if [ -f ${CLASSFILE}.py ]; then
                  # The provisioning up above has logic to put the deflect in the OPENBATON deflect pool. We will use a var.
                  DFLPOOL=OPENBATON

                  logger "deflect_configure: INFO: Attempting to adjust deflect pool size."
                  # This will not only provision the deflect but it will add it to the deflect pool, so no separate call needed.
                  (python3 ${CLASSFILE}.py ${DFLPOOL} 1>${CLASSFILE}.py.log 2>&1)
                  if [ $? -eq 0 ]; then
                     logger "deflect_configure:INFO: Deflect Pool ${DFLPOOL} successfully adjusted with new vtc count."
                  else
                     logger "deflect_configure:WARN: Unable to adjust deflect pool size for pool ${DFLPOOL}. Code $?."
                  fi
               else
                  logger "deflect_configure:ERROR: FileNotExists: ${CLASSFILE}"
                  popd
                  exit 1
               fi
            else
               logger "deflect_configure:ERROR: FileNotExists: ${CLASSFILE}"
               popd
               exit 1
            fi
         elif [ $? -eq 4 ]; then
            logger "deflect_configure:INFO: VTC ${VTCNAME} already provisioned (assumed correct)."
         else
            logger "deflect_configure:ERROR: Error in attempt to provision VTC ${VTCNAME}. Shell Code: $?"
            popd
            exit 1
         fi
      else
         logger "deflect_configure:ERROR: FileNotExists: ${CLASSFILE}"
         popd
         exit 1
      fi
   else
      logger "deflect_configure:ERROR: DirNotExists: ${RSTCLTDIR}"
      exit 1
   fi
else
   logger "deflect_configure:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

logger "deflect_configure:INFO: Successful implementation of deflect_configure script. Exiting 0."
exit 0
#set +x
