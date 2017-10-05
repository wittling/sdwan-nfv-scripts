#!/bin/bash

# It appears that this script gets cranked for every deflect that comes up.
# If this is in fact how the orchestrator is doing this, we can take advantage of this
# by making RESTful API calls to provision each one at their time of instantiation.

#env
#set -x
logger "bootstrapdsx_configure.bash: Greetings Deflect! I am Bootstrap DSX."
logger "bootstrapdsx_configure.bash: I see your Deflect Hostname has been assigned as: ${hostname}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX IP Address is: ${bootstrapdsx_dsxnet}."
logger "bootstrapdsx_configure.bash: It appears you will using the traffic interface: ${ifacetraffic}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Control Plane Interface is: ${bootstrapdsx_ifacectlplane}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Registration Port is: ${bootstrapdsx_portreg}"
logger "bootstrapdsx_configure.bash: My REST API Port is: ${bootstrapdsx_portrest}"

# export the variables
export hostname

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
         (python3 ${CLASSFILE}.py ${hostname} ${hostname} "no" 1>${CLASSFILE}.py.log 2>&1)
         if [ $? -eq 0 ]; then
            logger "bootstrap_configure:INFO: VTC ${hostname} provisioned!"
         elif [ $? -eq 4 ]; then
            logger "bootstrap_configure:INFO: VTC ${hostname} already provisioned (assumed correct)."
         else
            logger "bootstrap_configure:ERROR: Error in attempt to provision VTC ${hostname}. Shell Code: $?"
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
