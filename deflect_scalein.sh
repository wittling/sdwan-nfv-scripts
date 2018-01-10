#!/bin/bash
#env
#set -x

# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"

# Let us see what environment variables the orchestrator passes into this script...
env > ${RESTCLTDIR}/deflect_scalein.env

logger "deflect_scalein: Greetings Bootstrap DSX! I am a Deflect."
logger "deflect_scalein: My Deflect IP Address is: ${deflect_dflnet}" 
logger "deflect_scalein: I see your IP Address is: ${dsxnet}"
logger "deflect_scalein: I see your hostname is: ${hostname}"
logger "deflect_scalein: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "deflect_scalein: I will be sending data on port: ${deflect_portdata}" 
logger "deflect_scalein: I will be sending callp on port: ${deflect_portcallp}" 
logger "deflect_scalein: I will be using svc group and deflect pool: ${svcgroup}" 

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

logger "deflect_scalein:INFO: Attempting to provision VTC via REST interface"
python3 -V
if [ $? -eq 0 ]; then
   if [ -d ${RESTCLTDIR} ]; then
      pushd ${RESTCLTDIR}
      CLASSFILE=deflectpool
      if [ -f ${CLASSFILE}.py ]; then
         if [ ! -x ${CLASSFILE}.py ]; then
            chmod +x ${CLASSFILE}.py
         fi
         DVNRESTENV=".dvnrestenv"
         if [ -f ${DVNRESTENV} ]; then
            logger "deflect_scalein:INFO: Sourcing rest environment..."
            source "${DVNRESTENV}"
         else
            logger "deflect_scalein:INFO: Sourcing rest environment..."
            popd
            exit 1
         fi

         logger "deflect_scalein: INFO: Attempting to scale in the deflect pool target min and max."
         # We could use service pool but not sure if orchestrator passes this in on a scale event.
         # So we will set a variable here just to be safe for testing.
         export DFLPOOL=OPENBATON
         (python3 ${CLASSFILE}.py ${DFLPOOL} 1>${CLASSFILE}.py.log 2>&1)
         if [ $? -eq 0 ]; then
            logger "deflect_scalein:INFO: VTC ${VTCNAME} provisioned!"
            CLASSFILE=callp
            if [ -f ${CLASSFILE}.py ]; then
               if [ ! -x ${CLASSFILE}.py ]; then
                  chmod +x ${CLASSFILE}.py
               fi
            else
               logger "deflect_scalein:ERROR: FileNotExists: ${CLASSFILE}"
               popd
               exit 1
            fi
         else
            logger "deflect_scalein:ERROR: Error in attempt to set target min max on deflect pool."
            popd
            exit 1
         fi
      else
         logger "deflect_scalein:ERROR: FileNotExists: ${CLASSFILE}"
         popd
         exit 1
      fi
   else
      logger "deflect_scalein:ERROR: DirNotExists: ${RSTCLTDIR}"
      exit 1
   fi
else
   logger "deflect_scalein:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

logger "deflect_scalein:INFO: Successful implementation of deflect_scalein script. Exiting 0."
exit 0
#set +x
