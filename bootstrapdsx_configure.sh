#!/bin/bash

env
set -x
logger "bootstrapdsx_configure.bash: CONFIGURATION of the Bootstrap DSX"
logger "bootstrapdsx_configure.bash: Hostname: $bootstrapdsx_hostname"
logger "bootstrapdsx_configure.bash: Control Plane IP: $bootstrapdsx_dsxnet"
logger "bootstrapdsx_configure.bash: Control Plane Interface: $bootstrapdsx_ifacectlplane"
logger "bootstrapdsx_configure.bash: Reserved: $bootstrapdsx_reserved"
set +x
