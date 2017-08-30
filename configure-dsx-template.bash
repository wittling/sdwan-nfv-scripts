#!/bin/bash

# We assume on a base image that the software has been installed in default location.
# We probably do not want to go hunting around because what if someone has backed 
DVNPATH="/usr/local/dps"
DVNTMPLTREL="/cfg/vtc_reg_templates"
TMPLTFILE="vtc_config_template.json"

# A better way to do this is to pass it into the script as an arg
# Find out how to pass args into scripts through openbaton.
IFACE=eth0

# One would think getting an IP is easy. 
CURRIP=`ip addr show ${IFACE} | grep -Po 'inet \K[\d.]+'`
# We should validate this somehow. Maybe ping ourselves.
#RC=`ping -c 5 ${CURRIP}`
if [ $? -eq 0 ]; then 
   # TODO: We should probably check the actual IP here for 4 valid octets
   echo "INFO: Our current IP is valid: ${CURRIP}"
else
   echo "ERROR: Our current IP is NOT valid: ${CURRIP}"
   exit 1
fi   

echo "INFO: Checking for DVNHOME environment variable"
if [ -z ${DVNHOME} ]; then
   echo "WARNING: No DVNHOME environment variable set."
   echo "INFO: DVN PATH will assumed to be: ${DVNPATH}"
else
   echo "INFO: DVNHOME set to: ${DVNHOME}."
   DVNPATH=${DVNHOME}
fi

if [ -d ${DVNPATH} ]; then
   if [ -d ${DVNPATH}${DVNTMPLTREL} ]; then
      if [ -w ${DVNPATH}${DVNTMPLTREL}/${TMPLTFILE} ]; then
         # We will want to change the IP to OUR current IP Address
         # The DSX needs to have a static IP for this to be effective.
         pushd ${DVNPATH}${DVNTMPLTREL}
         # Temporary kluge because of something I cannot figure out with sed
         cp ${TMPLTFILE} ${TMPLTFILE}.tmp
         sed "s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/"$CURRIP"2/g" ${TMPLTFILE}.tmp > ${TMPLTFILE} 
         #sed 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/172\.31\.0\.22/g' ${TMPLTFILE} > /tmp/sed.out
         #sed -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/${CURRIP}/g' ${TMPLTFILE}
         if [ $? -eq 0 ]; then
            echo "INFO: IP Successfully replaced."
            exit 0
         fi
         popd
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
