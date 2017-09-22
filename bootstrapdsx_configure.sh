#!/bin/bash

#env
#set -x
logger "bootstrapdsx_configure.bash: Greetings Deflect! I am Bootstrap DSX."
logger "bootstrapdsx_configure.bash: I see your Deflect Hostname has been assigned as: ${hostname}"
logger "bootstrapdsx_configure.bash: My Bootstrap Hostname is: ${bootstrapdsx_hostname}."
logger "bootstrapdsx_configure.bash: My Bootstrap DSX IP Address is: ${bootstrapdsx_dsxnet}."
logger "bootstrapdsx_configure.bash: It appears you will using the traffic interface: ${ifacetraffic}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Control Plane Interface is: ${bootstrapdsx_ifacectlplane}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Registration Port is: ${bootstrapdsx_portreg}"
logger "bootstrapdsx_configure.bash: My REST API Port is: ${bootstrapdsx_portrest}"
logger "bootstrapdsx_configure.bash: When you contact me I will provision you and add you to a pool."

logger "bootstrapdsx_configure.bash: Goodbye! Tchuss!"
#set +x
