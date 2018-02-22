#!/bin/bash
#title           :l3gw_instantiate.sh
#author      :Wittling
#date            :2018
#version         :1.0   
#usage       :bash l3gw_instantiate.sh
#notes           :Service Orchestration Script
#bash_version    :2.4
#description     :See description further below.
#==============================================================================
# This script is invoked for each instantiation of the gateway if so specified.
#==============================================================================
#set -x

SCRIPTNAME="l3gw_instantiate"
logger "${SCRIPTNAME}:INFO:Configure LifeCycle Event Triggered!"

SCRIPTDIR="/opt/openbaton/scripts"
if [ ! -d ${SCRIPTDIR} ]; then
   SCRIPTDIR=${PWD}
fi

ENVFILE="${SCRIPTDIR}/${SCRIPTNAME}.env.$$"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
echo "====================================================" >> ${ENVFILE}
echo "Environment relevant to ${SCRIPTNAME}.sh script: " >> ${ENVFILE}
env >> ${ENVFILE}
echo "====================================================" >> ${ENVFILE}

logger "${SCRIPTNAME}:INFO: INSTANTIATION Script"

logger "${SCRIPTNAME}:INFO: Hostname: ${hostname}"
logger "${SCRIPTNAME}:INFO: wan1iface: ${wan1iface}"
logger "${SCRIPTNAME}:INFO: wan2iface: ${wan2iface}"
logger "${SCRIPTNAME}:INFO: laniface: ${laniface}"
logger "${SCRIPTNAME}:INFO: Data Port: ${portdata}" 
logger "${SCRIPTNAME}:INFO: CallP Port: ${portcallp}" 
logger "${SCRIPTNAME}:INFO: Service Type: ${svctyp}" 
logger "${SCRIPTNAME}:INFO: Service ID: ${svcid}" 
logger "${SCRIPTNAME}:INFO: Service Gateway Node: ${svcl3gnode}" 
logger "${SCRIPTNAME}:INFO: Service Destination Net: ${svcl3gdstnet}" 
logger "${SCRIPTNAME}:INFO: Service Destination Mask: ${svcl3gdstmask}" 
logger "${SCRIPTNAME}:INFO: Intercept IP: ${svcl3ginterceptip}" 
logger "${SCRIPTNAME}:INFO: Intercept IP: ${svcl3gproto}" 
logger "${SCRIPTNAME}:INFO: External Network Hint: ${extrnlhint}" 
logger "${SCRIPTNAME}:INFO: Internal Network Hint: ${intrnlhint}" 

DVNSERVICENAME=dvn

function getDefaultNic()
{
    local dfltnic 
    local rc
    dfltnic=`ip -4 r ls | grep default | grep -Po '(?<=dev )(\S+)'`
    rc=$?
    echo ${dfltnic}
    return ${rc}
}

# This function will take an IP and make sure that it is indeed a valid VNFC
# by checking to ensure it is set by the orchestrator in our environment
#
# returns 0 valid
# returns 1 invalid
# returns -1 error
function ipAssignedToVNFC
{
   local rc=1
   if [[ -z $1 ]]; then
      logger "${SCRIPTNAME}:ERROR: Argument Error. No parameter."
      rc=-1
   else
      IP=$1
      for LINE in `env`; do
         SRCH=`echo ${LINE} | grep ${IP}`
         if [ $? -eq 0 ]; then
            # logger "${SCRIPTNAME}.sh:DEBUG: Found IP ${IP} set to ${LINE}."
            NTWK=`echo ${SRCH} | cut -f 1 -d "="`
            if [ $? -eq 0 ]; then
               # logger "${SCRIPTNAME}.sh:DEBUG: IP assigned to VNFC ${NTWK}."
               rc=0
               echo ${NTWK}
            else
               logger "${SCRIPTNAME}:WARN: Error parsing IP from env var."
               rc=-1
            fi
            break
         fi  
      done
   fi

   if [[ $rc -eq 0 ]]; then
       return 0
   elif [[ $rc -eq 1 ]]; then
       return 1
   else
      return -1
   fi
   # should never reach here but is included to make sure we have a net
   return -1
}

# This could be a little dangerous to do. Why? Because if you have 2 or more interfaces on the
# Gateway and the default route happens to be inadvertently assigned to the internal LAN nic 
# rather than the WAN nic we could find ourselves in deep shit down the road.
#
# If the orchestrator sets the default route properly all the time then this is okay logic.
# TODO: investigate how the OpenStack and or OpenBaton assign the default route.
# Q. Is it the first nic to come up? 
# Q. Is it the first nic specified in the descriptor?
# Q. Maybe we can specify this IN the descriptor?
#
# TODO; Look into all of this. It is important to understand.
#
if [ -z "${wan1iface}" ]; then
   logger "${SCRIPTNAME}:WARN:No wan1iface variable passed in from orchestrator!"
   logger "${SCRIPTNAME}:WARN:Attempting to locate an interface that can be used with defgw."
   # DFLTNIC=`ip -4 r ls | grep default | grep -Po '(?<=dev )(\S+)'`
   DFLTNIC=$(getDefaultNic)
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:WARN:Found default gw interface ${DFLTNIC}.Attempting to use that."
      wan1iface=${DFLTNIC}
   else
      logger "${SCRIPTNAME}:ERROR:Unable to find an appropriate interface for DVN traffic."
      exit 1
   fi  
elif [ "${wan1iface}" == "lo" ]; then
   logger "${SCRIPTNAME}:ERROR:Invalid loopback interface specified in wan1iface."
   exit 1
else
   logger "${SCRIPTNAME}:INFO:wan1iface set to: ${wan1iface}."
   # Check the wan1iface and make sure it really exists.
   # If we have specified it properly in the descriptor it sure as hell should be. If it is not
   # we have a major problem. We could confer with the kernel but ip link does the job just fine.
   ip link show ${wan1iface}
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO:wan1iface: ${wan1iface} is a valid interface."
      # Is the interface up?
      KRNLSTFL=`find /sys/devices -name operstate | grep ${wan1iface}`
      if [ $? -eq 0 -a -f ${KRNLSTFL} ]; then
         OPRST=`cat ${KRNLSTFL}`
         logger "${SCRIPTNAME}:INFO: ${wan1iface} link status from kernel is ${OPRST}."
         if [ ${OPRST} != "up" -a ${OPRST} != "UP" -a ${OPRST} != "Up" ]; then
            logger "${SCRIPTNAME}:ERROR: ${wan1iface} link status is not up: ${OPRST}."
            # Yes we could get really cute and manage the interface and try to set link state up and so on.
            # But again, if we are in situations where we cannot find interfaces or the states are not 
            # initialized properly we are kind of in deep shit and need to just bail out.
            # Because OpenStack and OpenBaton should be managing this stuff.
            exit 1
         else
            # If we have gotten here we know we have the interface and its up. Now, does this interface
            # have the default route? This gets tricky because it is possible to have NO default routes
            # on a gateway. In fact, one of the GWs for a customer I set up have only static routes and
            # no default route. But what we do NOT want to see is the orchestrator or OpenStack putting 
            # the default route on the internal NIC that might be specified in an adjacent VLD rather than the 
            # external NIC.
            DFLTNIC=$(getDefaultNic)
            if [ $? -eq 0 -a ${DFLTNIC} == ${wan1iface} ]; then
               logger "${SCRIPTNAME}:INFO:${wan1iface} is default nic."
            else
               logger "${SCRIPTNAME}:INFO:${wan1iface} NOT default nic. ${DFLTNIC} is default nic. Problem. Exiting."
               exit 1
            fi  
         fi 
      else
         logger "${SCRIPTNAME}:ERROR:Could not find interface operstate file to determine interface status."
         exit 1
      fi
   else
      logger "${SCRIPTNAME}:ERROR:Interface ${wan1iface} does not appear to be a valid interface on VFNM."
      exit 1
   fi
fi

# Now that we know we have a valid WAN IP address and that it is indeed the default nic, we can
# do a quick check to make sure it is a valid IP passed in from orchestrator and assigned to a VNFC.
# It should be. If it passes THIS test, we can use this as our unique identifying ip address for 
# DVN purposes.
MYIP="127.0.0.1"
VNFC="local"
# We may have multiple IPs on a given interface! So this needs to be a loop.
for IP in `ip -4 a show ${wan1iface} | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`; do
   # If we have multiple IPs on our WAN we will get really confused about our identity 
   # And it can if you are running VRRP or something like that. If we are running VRRP 
   # the virtual IP used for failover is almost always the subsequent address on the nic.
   # But we could get confused about who we are if we see multiple IPs on the interface.
   # So I think for now we will exit if we see this occur.
   if [ ${MYIP} == "127.0.0.1" ]; then
      MYIP=${IP}
   else
      logger "${SCRIPTNAME}:ERROR: Multiple IPs assigned to ${wan1iface}. Unexpected. Exiting." 
      exit 1
   fi

   VNFC=$(ipAssignedToVNFC ${IP}) 
   if [ $? -eq 0 ]; then
      logger "${SCRIPTNAME}:INFO: IP: ${IP} assigned to ${VNFC}." 
      MYIP=${IP}
      break
   elif [ $? -eq 1 ]; then
      logger "${SCRIPTNAME}:DEBUG: IP: ${IP} NOT assigned to ${VNFC}." 
   elif [ $? -eq -1 ]; then
      logger "${SCRIPTNAME}:ERROR: Error calling function ipAssignedToVNFC with arg: ${IP}." 
      exit 1
   else
      logger "${SCRIPTNAME}:ERROR: Unexpected return code from ipAssignedToVNFC. Exiting." 
      exit 1
   fi
done

if [ "${MYIP}" == "127.0.0.1" ]; then
   logger "${SCRIPTNAME}:ERROR: No IP Address assigned to interface: ${wan1iface}."
   exit 1
fi

if [ "${VNFC}" == "local" ]; then
   logger "${SCRIPTNAME}:ERROR: IP Address ${MYIP} not assigned to recognizable VNFC."
   exit 1
else
   logger "${SCRIPTNAME}:INFO: IP Address ${MYIP} assigned to VNFC: ${VNFC}."
fi

logger "${SCRIPTNAME}:INFO: A process is resetting the sysctl.conf file." 
logger "${SCRIPTNAME}:INFO: We will attempt to set the socket buffer receive parm here."
logger "${SCRIPTNAME}:INFO: This will alleviate an alarm that complains about this parm being set too low."

# Obviously we need to be running this script as root to do this. Fortunately we are.
PARMPATH='/proc/sys/net/core/rmem_max'
echo 'net.core.rmem_max=2048000' >> /etc/sysctl.conf
sysctl -p 
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO: Call to sysctl appears to be successful."
   logger "${SCRIPTNAME}:INFO: Verifying Socket Buffer Receive Parameter."
   echo "Socket Buffer Receive Parm rmem_max is now: `cat ${PARMPATH}`" | logger
else
   logger "${SCRIPTNAME}:WARN: Call to sysctl appears to have failed."
   logger "${SCRIPTNAME}:WARN: Please set net.core.rmem_max parameter to 2048000 manually to avoid alarm."
fi

# If dvn is autocranked we will want to stop it until the configure event cycle.
#RESP=`systemctl is-enabled ${DVNSERVICENAME}`
# to avoid shell issue
#if [ -z "${RESP}" ]; then
#   RESP=invalid
#fi
#if [ $? -eq 0 -a "${RESP}" == "enabled" ]; then
#   systemctl stop ${DVNSERVICENAME}
#else
#   if [ ${RESP} == "disabled" ]; then
#      logger "${SCRIPTNAME}:WARN: Service ${DVNSERVICENAME} disabled. Enabling."
#      systemctl enable ${DVNSERVICENAME}
#      if [ $? -ne 0 ]; then
#         logger "${SCRIPTNAME}:ERROR: Unable to enable service ${DVNSERVICENAME}. Enabling."
#         exit 1
#      fi
#      # Enabling the service should not start it but we will do this just to be sure.
#      systemctl stop ${DVNSERVICENAME}
#   else
#      logger "${SCRIPTNAME}:ERROR: Service ${DVNSERVICENAME} unrecognized. Exiting."
#      exit 1
#   fi
#fi
systemctl enable dvn
systemctl stop dvn

logger "${SCRIPTNAME}:INFO: End of Script. Return Code 0."
exit 0
