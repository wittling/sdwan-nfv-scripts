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
export bootstrapdsx_portreg
export bootstrapdsx_portrest

logger "bootstrap_configure:INFO: Successful implementation of bootstrapdsx_configure script. Exiting 0."
exit 0
#set +x
