#!/bin/bash

# We assume on a base image that the software has been installed in default location.
# We probably do not want to go hunting around because what if someone has backed 
DVNPATH="/usr/local/dps"
DVNTMPLTREL="/cfg/vtc_reg_templates"
TMPLTFILE="vtc_config_template.json"

# One would think getting an IP is easy. 
CURRIP=`ip addr show eth0 | grep -Po 'inet \K[\d.]+'`
# We should validate this somehow. Maybe ping ourselves.
RC=`ping ${CURRIP}`
if [ ${RC} -eq 0 ]; then 
   echo "INFO: Our current IP is valid: ${CURRIP}"
else
   echo "ERROR: Our current IP is NOT valid: ${CURRIP}"
   exit 1
fi   

echo "INFO: Checking for DVNHOME environment variable"
if [ -z DVNHOME ]; then
   echo "WARNING: No DVNHOME environment variable set."
   echo "INFO: DVN PATH will assumed to be: ${DVNPATH}"
else
   echo "INFO: DVNHOME set to: ${DVNHOME}."
   DVNPATH=${DVNHOME}
fi

if [ -d ${DVNPATH}  ]; then
   if [ -d ${DVNPATH}${DVNTMPLTREL} ]; then
      if [ -w ${DVNPATH}${DVNTMPLTREL}/${TMPLTFILE} ]; then
         # We will want to change the IP to OUR current IP Address
         # The DSX needs to have a static IP for this to be effective.
         pushd ${DVNPATH}${DVNTMPLTREL}/vtc
         sed -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/${CURRIP}/g' ${TMPLTFILE}
         if [ $? -eq 0 ];
            echo "INFO: IP Successfully replaced."
            exit 0
         fi
      else
         echo "ERROR: File ${TMPLTFILE} not existent or writable in directory ${DVNPATH}${DVNTMPLTREL}"
         exit 1
      fi 
   else
      echo "ERROR: no directory ${DVNPATH}${DVNTMPLTREL} exists."
      exit 1 
   fi
else
   echo "ERROR: no directory ${DVNPATH} exists."
   exit 1
fi
