#!/bin/bash

#env
#set -x
logger "bootstrapdsx_configure.bash: DEFLECT CONFIGURATION - SOME PARMS PASSED from DSX!"
logger "bootstrapdsx_configure.bash: Hostname: ${hostname}"
logger "bootstrapdsx_configure.bash: DSX IP (passed param): ${bootstrapdsx_dsxnet}"
logger "bootstrapdsx_configure.bash: Traffic Interface: ${ifacetraffic}"
logger "bootstrapdsx_configure.bash: DSX Control Plane Interface (passed param): ${bootstrapdsx_ifacectlplane}"
logger "bootstrapdsx_configure.bash: Registration Port (passed param): ${bootstrapdsx_regport}"
logger "bootstrapdsx_configure.bash: REST API Port (passed param): ${bootstrapdsx_restport}"
#set +x
