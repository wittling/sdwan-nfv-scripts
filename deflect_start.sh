#!/bin/bash

SCRIPTNAME="deflect_start.sh"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:Start LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/deflect_start.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

# This should trigger the autoscaling feature
if [ -f ${SCRIPTDIR}/loadcpu.bash ]; then
   pushd ${SCRIPTDIR}
   nohup loadcpu.bash 2 &
fi

# No sense wasting cycles
if [ -z ${svrzabbix} ]; then
   logger "${SCRIPTNAME}:ERROR:No Zabbix IP Passed to VM"
   exit 1
else
   logger "${SCRIPTNAME}:INFO:Zabbix Server: $svrzabbix"
fi

# It turns out that the OpenBaton orchestrator installs the wrong version of Zabbix (2.2)
# It also installs the SERVER - and not the agent, which I do not understand (need to look into this).
# Maybe this is the yum default but we are running server version 3.
# So - we need to uninstall Zabbix 2.x first and then install the proper version of the Zabbix Agent.
# You cannot have version 2.2 of Zabbix and 3.x of the agent because of conflicts.

rpm -qa | grep -i zabbix
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:INFO:Removing legacy zabbix packages"
   yum -y remove zabbix*
fi

# We could check return code above but lets make double sure
rpm -qa | grep -i zabbix
if [ $? -eq 0 ]; then
   logger "${SCRIPTNAME}:ERR:Failed to remove zabbix packages"
   exit 1
fi

# Now we need to configure it.
if [ -x /usr/bin/yum ]; then
  # Good practice to update but too time costly and frankly, risky.
  # yum -y update
  logger "${SCRIPTNAME}:INFO:Installing zabbix repo"
  rpm -ivh http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm
  logger "${SCRIPTNAME}:INFO:Installing zabbix-agent"
  yum -y install zabbix-agent

  # Precautionary in case it is cranked upon install.
  systemctl stop zabbix-agent

  # Back up the config file
  ZABX_AGNT_CONF=/etc/zabbix/zabbix_agentd.conf
  if [ -f ${ZABX_AGNT_CONF} ]; then
     DIRNM=`dirname ${ZABX_AGNT_CONF}`    
     FLNM=`basename ${ZABX_AGNT_CONF}`
     pushd ${DIRNM}    
     cp ${FLNM} ${FLNM}.bak
     popd
  else
     logger "${SCRIPTNAME}:ERR:FileNotExists:Zabbix Config File ${ZABX_AGNT_CONF}"
     exit 1
  fi

  logger "${SCRIPTNAME}:INFO:Configuring Zabbix Agent"

  ZABBIXCLEAN=true

  # A brand spanking new deployment always has the Zabbix Server directive uncommented and set to local host.
  # We will need to set that to the appropriate server.
  (sed -i 's+^Server=127\.0\.0\.1+#&\nServer='"${svrzabbix}"'+' ${ZABX_AGNT_CONF})
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring zabbix server parm in zabbix agent"
     ZABBIXCLEAN=false
  fi

  # Disabling active agent mode because it seems that hosts will not show up as monitored hosts unless
  # they are passive agents.
  #
  # Based on testing a new deployment uncomments and sets this parameter - assumes active by default.
  # We will assume that the VM needs to be an active agent and not a passive agent.
  #(sed -i 's+ServerActive=127\.0\.0\.1+#&\nServerActive='"${svrzabbix}"'+' ${ZABX_AGNT_CONF})
  #
  # Just comment it out.
  (sed -i 's+ServerActive=127\.0\.0\.1+#&+' ${ZABX_AGNT_CONF})
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring zabbix server active parm in zabbix agent"
     ZABBIXCLEAN=false
  fi

  # Next we need to change the ListenIP
  # It does not appear the dflnet is passed in by orchestrator in this stage of lifecycle so we must get the IP.
  LISTENIP=`hostname -I`
  (sed -i 's+^#*.ListenIP=0\.0\.0\.0*.$+&\nListenIP='"${LISTENIP}"'+' ${ZABX_AGNT_CONF})
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring listenip parm in zabbix agent"
     ZABBIXCLEAN=false
  fi

  # SourceIP is a non-mandatory parm but it is probably a good idea to set it to the specific IP assigned to the VM.
  (sed -i 's+^#*.SourceIP=*.$+&\nSourceIP='"${LISTENIP}"'+' ${ZABX_AGNT_CONF})
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring source ip parm in zabbix agent"
     ZABBIXCLEAN=false
  fi

  # Hostname is an env var but at this stage it should be set and we can use the command.
  (HOSTNAME=`hostname` && sed -i 's+^Hostname=Zabbix [s|S]erver+Hostname='$HOSTNAME'+' ${ZABX_AGNT_CONF})
  # We could also just pound it out and let it use system hostname. That is an option also.
  # (sed -i 's+^Hostname+# &+' $ZABX_AGNT_CONF})
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring zabbix hostname"
     ZABBIXCLEAN=false
  fi

  # If we cannot ping but got the variable we will assume maybe server is down and stay legitimate w a warning.
  ping -c 10 -q ${svrzabbix}
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:WARN:Could not ping zabbix server at ${svrzabbix}!"
  fi

  if [ ${ZABBIXCLEAN} ]; then
     logger "${SCRIPTNAME}:INFO:Zabbix looks clean. Starting agent."
     systemctl enable zabbix-agent
     systemctl start zabbix-agent
  else
     logger "${SCRIPTNAME}:WARN:Not starting Zabbix Agent due to configuration errors."
  fi
fi

# This should trigger the autoscaling feature
if [ -f ${SCRIPTDIR}/loadcpu.bash ]; then
   pushd ${SCRIPTDIR}
   nohup loadcpu.bash 2 &
fi

#set +x
exit 0
