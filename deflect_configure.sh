#!/bin/bash
#env
#set -x

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
logger "Goodbye! Tchuss!"

# export the variables
export hostname
export deflect_dflnet
export deflect_portdata
export deflect_portcallp

# OpenBaton likes to name the hosts with an appended hyphen and generated uid of some sort
# Not sure if rest likes hyphens so we will grab the suffix id and use that for provisioning. 
NODENUM="echo ${deflect_dflnet} | cut -f 4 -d '.'"
export VTCNAME=OPNBTN${NODENUM}

logger "bootstrapdsx_configure:INFO: Attempting to provision VTC via REST interface"
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
            logger "bootstrapdsx_configure:INFO: Sourcing rest environment..."
            source "${DVNRESTENV}"
         else
            logger "bootstrapdsx_configure:INFO: Sourcing rest environment..."
            popd
            exit 1
         fi

         logger "bootstrapdsx_configure: INFO: Attempting to provision new vtc ${hostname}."
         (python3 ${CLASSFILE}.py ${VTCNAME} ${VTCNAME} "no" 1>${CLASSFILE}.py.log 2>&1)
         if [ $? -eq 0 ]; then
            logger "bootstrap_configure:INFO: VTC ${VTCNAME} provisioned!"
         elif [ $? -eq 4 ]; then
            logger "bootstrap_configure:INFO: VTC ${VTCNAME} already provisioned (assumed correct)."
         else
            logger "bootstrap_configure:ERROR: Error in attempt to provision VTC ${VTCNAME}. Shell Code: $?"
            popd
            exit 1
         fi
      else
         logger "bootstrap_configure:ERROR: FileNotExists: ${CLASSFILE}"
         popd
         exit 1
      fi
   else
      logger "bootstrap_configure:ERROR: DirNotExists: ${RSTCLTDIR}"
      exit 1
   fi
else
   logger "bootstrap_configure:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

logger "bootstrap_configure:INFO: Successful implementation of bootstrapdsx_configure script. Exiting 0."
exit 0
#set +x
