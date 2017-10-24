#!/bin/bash

#env
#set -x

logger "bootstrapdsx_heal.bash:INFO:HEAL LifeCycle Event Triggered!"

ENVFILE="/opt/openbaton/scripts/bootstrapdsx_heal.env"
logger "bootstrapdsx_heal.bash:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

#set +x
exit 0
