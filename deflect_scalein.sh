#!/bin/bash
#env
#set -x

# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

SCRIPTNAME="deflect_scalein"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:SCALE_IN LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"

# Let us see what environment variables the orchestrator passes into this script...
env > /opt/openbaton/scripts/deflect_scalein.env

logger "deflect_scalein: Greetings Bootstrap DSX! I am a Deflect."
logger "deflect_scalein: My Deflect IP Address is: ${deflect_dflnet}" 
logger "deflect_scalein: I see your IP Address is: ${dsxnet}"
logger "deflect_scalein: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "deflect_scalein: I will be sending data on port: ${deflect_portdata}" 
logger "deflect_scalein: I will be sending callp on port: ${deflect_portcallp}" 
logger "deflect_scalein: I will be using svc group and deflect pool: ${svcgroup}" 
logger "deflect_scalein: Hostname being scaled in is: ${removing_hostname}"
logger "deflect_scalein: IP being scaled in is: ${removing_dflnet}"

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp
export svcgroup
export removing_hostname
export removing_dflnet

function adjustDeflectPool
{
   CLASSFILE=deflectpool
   if [ -f ${CLASSFILE}.py ]; then
      if [ ! -x ${CLASSFILE}.py ]; then
         chmod +x ${CLASSFILE}.py
      fi

      # Consider using svcgroup here. Check env to make sure it is being passed in.
      logger "deflect_scalein: INFO: Attempting to scale in the deflect pool target min and max."
      (python3 ${CLASSFILE}.py ${svcgroup} 1>${CLASSFILE}.py.log 2>&1)
      if [ $? -eq 0 ]; then
         logger "deflect_scalein:INFO: Deflect Pool Size Adjusted to reflect removal of: ${removing_hostname}."
      else
         logger "deflect_scalein:ERROR: Error in attempt to adjust deflect pool size."
         return 1
      fi
   else
      logger "deflect_scalein:ERROR: FileNotExists: ${CLASSFILE}"
      return 1
   fi
}

function deprovElement
{
   if [ -z $1 ]; then
      logger "deflect_scalein:removeDartElement:ERROR:Invalid or NoneExistant Argument: Arg1:Classfile"
      return 1
   fi

   if [ -z $2 ]; then
      logger "deflect_scalein:removeDartElement:ERROR:Invalid or NoneExistant Argument: Arg2:Variable"
      return 1
   fi

   CLASSFILE=$1
   if [ -f ${CLASSFILE}.py ]; then
      if [ ! -x ${CLASSFILE}.py ]; then
         chmod +x ${CLASSFILE}.py
      fi

      # Consider using svcgroup here. Check env to make sure it is being passed in.
      logger "deflect_scalein: INFO: Attempting to call Python Script: ${CLASSFILE} with arg $2."
      (python3 ${CLASSFILE}.py $2 1>${CLASSFILE}.py.log 2>&1)
      if [ $? -eq 0 ]; then
         logger "deflect_scalein:INFO: Successful return code calling Python script."
      else
         logger "deflect_scalein:ERROR: Error calling Python script: ${CLASSFILE} with argument: $2:Code  is: $?"
         return 1
      fi
   else
      logger "deflect_scalein:ERROR: FileNotExists: ${CLASSFILE}"
      return 1
   fi
}


logger "deflect_scalein:INFO: Attempting to provision VTC via REST interface"
python3 -V
if [ $? -eq 0 ]; then
   if [ -d ${RESTCLTDIR} ]; then
      pushd ${RESTCLTDIR}

      DVNRESTENV=".dvnrestenv"
      if [ -f ${DVNRESTENV} ]; then
         logger "deflect_scalein:INFO: Sourcing rest environment..."
         source "${DVNRESTENV}"
      else
         logger "deflect_scalein:ERROR: Error Sourcing rest environment. File Not Found: ${DVNRESTENV}."
         popd
         exit 1
      fi
      
      # Call adjustDeflect
      adjustDeflectPool
      if [ $? -eq 1 ]; then
         popd
         exit 1
      fi

      # We tend to name all of these after the service group at least for purposes of initial prototyping.
    
      ELEMENTNAME=
      deprovElement callp $svcgroup
      if [ $? -eq 1 ]; then
         popd
         exit 1
      fi
      deprovElement deflect $svcgroup
      if [ $? -eq 1 ]; then
         popd
         exit 1
      fi
      deprovElement rxtxnode $svcgroup
      if [ $? -eq 1 ]; then
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
