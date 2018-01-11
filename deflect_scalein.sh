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
logger "deflect_scalein: Hostname being scaled in is: ${remove_hostname}"
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
            logger "deflect_scalein:ERROR: Error Sourcing rest environment. File Not Found: ${DVNRESTENV}."
            popd
            exit 1
         fi

         # Consider using svcgroup here. Check env to make sure it is being passed in.
         logger "deflect_scalein: INFO: Attempting to scale in the deflect pool target min and max."
         export DFLPOOL=OPENBATON
         (python3 ${CLASSFILE}.py ${DFLPOOL} 1>${CLASSFILE}.py.log 2>&1)
         if [ $? -eq 0 ]; then
            logger "deflect_scalein:INFO: Deflect Pool Size Adjusted to reflect removal of: ${remove_hostname}."
         else
            logger "deflect_scalein:ERROR: Error in attempt to adjust deflect pool size."
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
