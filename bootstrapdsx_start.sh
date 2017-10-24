#!/bin/bash

SCRIPTNAME="bootstrapdsx_start.sh"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:Start LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/bootstrapdsx_start.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

#set +x
exit 0
