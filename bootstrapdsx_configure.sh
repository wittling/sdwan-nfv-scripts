#!/bin/bash

#env
#set -x
logger "bootstrapdsx_configure.bash: CONFIGURATION"
logger "bootstrapdsx_configure.bash: Hostname: ${hostname}"
logger "bootstrapdsx_configure.bash: DSX IP: ${bootstrapdsx_dsxnet}"
logger "bootstrapdsx_configure.bash: Traffic Interface: ${ifacetraffic}"
logger "bootstrapdsx_configure.bash: DSX Control Plane Interface: ${ifacectlplane}"
logger "bootstrapdsx_configure.bash: Registration Port: ${bootstrapdsx_regport}"
#set +x
