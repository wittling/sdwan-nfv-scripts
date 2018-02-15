#!/bin/bash
#title           :deflect_scalein.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash deflect_scalein.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is called whenever a specified scalein event occurs
# on a deflect.
#==============================================================================
#env
#set -x

SCRIPTNAME="deflect_scalein"
logger "${SCRIPTNAME}:INFO:SCALE_IN LifeCycle Event Triggered!"

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

RESTCLTDIR="/usr/local/dart-rest-client/local-client-projects"

logger "${SCRIPTNAME}: Hostname being scaled in is: ${removing_hostname}"
logger "${SCRIPTNAME}: IP being scaled in is: ${removing_dflnet}"

# export the variables
export removing_hostname
export removing_dflnet

function adjustPool
{
   CLASSFILE=deflectpool
   if [ -f ${CLASSFILE}.py ]; then
      if [ ! -x ${CLASSFILE}.py ]; then
         chmod +x ${CLASSFILE}.py
      fi

      # Consider using svcgroup here. Check env to make sure it is being passed in.
      logger "${SCRIPTNAME}: INFO: Attempting to scale in the deflect pool target min and max."
      (python3 ${CLASSFILE}.py ${svcgroup} 1>${CLASSFILE}.py.log 2>&1)
      if [ $? -eq 0 ]; then
         logger "${SCRIPTNAME}:INFO: Deflect Pool Size Adjusted to reflect removal of: ${removing_hostname}."
      else
         logger "${SCRIPTNAME}:ERROR: Error in attempt to adjust deflect pool size."
         return 1
      fi
   else
      logger "${SCRIPTNAME}:ERROR: FileNotExists: ${CLASSFILE}"
      return 1
   fi
   return 0
}

function deprovElement
{
   if [ -z $1 ]; then
      logger "${SCRIPTNAME}:removeDartElement:ERROR:Invalid or NoneExistant Argument: Arg1:Element"
      return 1
   fi

   if [ -z $2 ]; then
      logger "${SCRIPTNAME}:removeDartElement:ERROR:Invalid or NoneExistant Argument: Arg2:Variable"
      return 1
   fi

   CLASSFILE=$1
   ID=$2
   if [ ! -f ${CLASSFILE}.py ]; then
      logger "${SCRIPTNAME}:ERROR: FileNotExists: ${CLASSFILE}"
      return 1
   fi

   if [ ! -x ${CLASSFILE}.py ]; then
      chmod +x ${CLASSFILE}.py
   fi

   # Consider using svcgroup here. Check env to make sure it is being passed in.
   logger "${SCRIPTNAME}: INFO: Attempting to call Python Script: ${CLASSFILE} with arg $2."
   if [ $1 == "callp" ]; then
      (python3 ${CLASSFILE}.py --operation deprovision --callpid ${ID} 1>${CLASSFILE}.py.log 2>&1)
   elif [ $1 == "deflect" ]; then
      (python3 ${CLASSFILE}.py --operation deprovision --dflid ${ID} 1>${CLASSFILE}.py.log 2>&1)
   elif [ $1 == "rxtxnode" ]; then
      (python3 ${CLASSFILE}.py --operation deprovision --nodeid ${ID} 1>${CLASSFILE}.py.log 2>&1)
   else
      logger "${SCRIPTNAME}:ERROR:deprovElement:Unrecognized element."
      return 1
   fi

   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO: Successful return code calling ${CLASSFILE} deprov operation:ID $2."
   else
      logger "${SCRIPTNAME}:ERROR: Error calling: ${CLASSFILE} deprov operation:ID $2:Code  is: $?"
      return 1
   fi
   return 0
}

logger "${SCRIPTNAME}:INFO: Attempting to provision VTC via REST interface"
python3 -V
if [ $? -ne 0 ]; then
   logger "${SCRIPTNAME}:ERROR: FileNotExists: Python3 Not Installed"
   exit 1
fi

if [ ! -d ${RESTCLTDIR} ]; then
   logger "${SCRIPTNAME}:ERROR: DirNotExists: ${RSTCLTDIR}"
   exit 1
fi

pushd ${RESTCLTDIR}

DVNRESTENV=".dvnrestenv"
if [ -f ${DVNRESTENV} ]; then
   logger "${SCRIPTNAME}:INFO: Sourcing rest environment..."
   source "${DVNRESTENV}"
else
   logger "${SCRIPTNAME}:ERROR: Error Sourcing rest environment. File Not Found: ${DVNRESTENV}."
   popd
   exit 1
fi

# #############################      
# Which should we be doing first? Deprovisioning and THEN adjusting the pool? 
# Or the other way around? We will adjust the pool first.
# #############################      

# Call adjustPool
adjustPool
if [ $? -eq 1 ]; then
   popd
   exit 1
fi

# We know the IP of the element being scaled in. But we do not know its name. Actually we DO
# know its name. Now. But we did not know it at spin up event so we had to use a convention to
# name it. So we have to reverse into that convention to deprovision it.
NODENUM=`echo ${removing_dflnet} | cut -f2-4 -d "." | sed 's+\.+x+'`
if [ $? -ne 0 ]; then
   logger
   exit 1
fi

FULLDEPROV=true
for element in callp deflect rxtxnode
do
   if [ $element -eq "callp" ]; then
      export NODENAME=CP${NODENUM}
   elif [ $element -eq "deflect" ]; then
      export NODENAME=DFL${NODENUM}
   elif [ $element -eq "rxtxnode" ]; then
      export NODENAME=OPNBTN${NODENUM}
   fi

   deprovElement $element ${NODENAME}
   if [ $? -ne 0 ]; then
      logger "${SCRIPTNAME}:ERROR:Error deprovisioning ${element}."
      FULLDEPROV=false 
   fi
done

if [ ! ${FULLDEPROV} ]; then
   popd
   exit 1
fi

logger "${SCRIPTNAME}:INFO: Successful implementation of deflect_scalein script. Exiting 0."
exit 0
#set +x
