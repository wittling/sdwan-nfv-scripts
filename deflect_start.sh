#!/bin/bash

SCRIPTNAME="deflect_start.sh"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:Start LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/deflect_start.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

# This should trigger the autoscaling feature
if [ -f ${SCRIPTDIR}/loadcpu.bash ]; then
   pushd ${SCRIPTDIR}
   nohup loadcpu.bash 2 &
fi

#set +x
exit 0
