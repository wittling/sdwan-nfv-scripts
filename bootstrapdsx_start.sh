#!/bin/bash

SCRIPTNAME="bootstrapdsx_start.sh"
SCRIPTDIR="/opt/openbaton/scripts"
#env
#set -x

logger "${SCRIPTNAME}:INFO:Start LifeCycle Event Triggered!"

ENVFILE="${SCRIPTDIR}/bootstrapdsx_start.env"
logger "${SCRIPTNAME}:INFO:Dumping environment to ${ENVFILE}!"
env > ${ENVFILE}

# No sense wasting cycles
if [ -z $zabbixsvr ]; then
   logger "${SCRIPTNAME}:ERROR:No Zabbix IP Passed to VM"
   exit 1
else
   logger "${SCRIPTNAME}:INFO:Zabbix Server: $zabbixsvr"
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
  rpm -ivh http://repo.zabbix.com/zabbix/2.4/rhel/6/x86_64/zabbix-release-2.4-1.el6.noarch.rpm
  logger "${SCRIPTNAME}:INFO:Installing zabbix-agent"
  yum -y install zabbix-agent

  # Precautionary in case it is cranked upon install.
  systemctl stop zabbix-agent

  ZABBIXCLEAN=true
  logger "${SCRIPTNAME}:INFO:Configuring Zabbix Agent"
  sed -i 's/Server=127.0.0.1/Server=${zabbixsvr}/' /etc/zabbix/zabbix_agentd.conf
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring zabbix server"
     ZABBIXCLEAN=false
  fi

  sed -i 's/ServerActive=127.0.0.1/ServerActive=${zabbixsvr}/' /etc/zabbix/zabbix_agentd.conf
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring zabbix active agent"
     ZABBIXCLEAN=false
  fi

  # Hostname is an env var but at this stage it should be set and we can use the command.
  HOSTNAME=`hostname` && sed -i "s/Hostname=Zabbix\ server/Hostname=$HOSTNAME/" /etc/zabbix/zabbix_agentd.conf
  if [ $? -ne 0 ]; then
     logger "${SCRIPTNAME}:ERR:Error configuring zabbix hostname"
     ZABBIXCLEAN=false
  fi

  # If we cannot ping but got the variable we will assume maybe server is down and stay legitimate w a warning.
  ping -c 10 -q ${zabbixsvr}
  if [ $? -eq 0 ]; then
     logger "${SCRIPTNAME}:WARN:Could not ping zabbix server at ${zabbixsvr}!"
  fi

  if [ ${ZABBIXCLEAN} ]; then
     systemctl enable zabbix-agent
     systemctl start zabbix-agent
  else
     logger "${SCRIPTNAME}:WARN:Not starting Zabbix Agent due to configuration errors."
     exit 1
  fi
fi

#set +x
exit 0
