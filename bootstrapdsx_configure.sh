#!/bin/bash

#env
#set -x
logger "bootstrapdsx_configure.bash: Greetings Deflect! I AM Bootstrap DSX...here to configure you!"
logger "bootstrapdsx_configure.bash: I see your Deflect Hostname has been assigned as: ${hostname}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX IP Address is: ${bootstrapdsx_dsxnet}."
logger "bootstrapdsx_configure.bash: It appears you will using the traffic interface: ${ifacetraffic}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Control Plane Interface is: ${bootstrapdsx_ifacectlplane}"
logger "bootstrapdsx_configure.bash: My Bootstrap DSX Registration Port is: ${bootstrapdsx_portreg}"
logger "bootstrapdsx_configure.bash: My REST API Port is: ${bootstrapdsx_portrest}"
logger "bootstrapdsx_configure.bash: Goodbye! Tchuss!"
#set +x
