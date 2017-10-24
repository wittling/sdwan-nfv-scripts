#!/bin/bash

#env
#set -x

logger "bootstrapdsx_start.bash:INFO:Start LifeCycle Event Triggered!"

ENVFILE="/opt/openbaton/scripts/bootstrapdsx_start.env"
logger "bootstrapdsx_start.bash:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

#set +x
exit 0
