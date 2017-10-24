#!/bin/bash

SCRIPTNAME="bootstrapdsx_heal.sh"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:HEAL LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/bootstrapdsx_heal.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

#set +x
exit 0
