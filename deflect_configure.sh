#!/bin/bash

logger "deflect_configure: Bootstrap DSX CONFIGURATION - Some parms passed in from Deflect!"

logger "deflect_configure: Hostname: ${hostname}"
logger "deflect_configure: IP Address: ${dflnet}" 
logger "deflect_configure: Ctl Plane Interface: ${ifacectlplane}" 
logger "deflect_configure: DSX IP Address: ${bootstrapdsx_dsxnet}"
logger "deflect_configure: DSX Reg Port (passed param) ${bootstrapdsx_regport}"
logger "deflect_configure: DSX REST API Port (passed param): ${bootstrapdsx_restport}"
