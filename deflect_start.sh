#!/bin/bash

#env
#set -x

logger "deflect_start.bash:INFO:Start LifeCycle Event Triggered!"

ENVFILE="/opt/openbaton/scripts/deflect_start.env"
logger "deflect_start.bash:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

#set +x
exit 0
