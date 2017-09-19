#!/bin/bash

env
set -x
logger "bootstrapdsx_configure.bash: CONFIGURATION of the Bootstrap DSX"
logger "bootstrapdsx_configure.bash: Hostname: $deflect_hostname"
logger "bootstrapdsx_configure.bash: Control Plane IP: $bootstrapdsx_dsxnet"
logger "bootstrapdsx_configure.bash: Control Plane Interface: $deflect_ifacetraffic"
logger "bootstrapdsx_configure.bash: Reserved: $deflect_reserved"
set +x
