#!/bin/bash

logger "deflect_configure: Greetings Bootstrap DSX! I am a Deflect."
logger "deflect_configure: I see your hostname is: ${hostname}"
logger "deflect_configure: My hostname is: ${deflect_hostname}"
logger "deflect_configure: My Deflect IP Address is: ${deflect_dflnet}" 
logger "deflect_configure: I see your IP Address is: ${dsxnet}"
logger "deflect_configure: It appears you will be using the ctl plane interface: ${ifacectlplane}" 
logger "deflect_configure: I will be sending data on port: ${deflect_portdata}" 
logger "deflect_configure: I will be sending callp on port: ${deflect_portcallp}" 
logger "Goodbye! Tchuss!"
