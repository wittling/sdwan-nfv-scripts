#!/bin/bash

SCRIPTNAME=almostnothing.bash
MSG="Script that does almost nothing"

# send string to std out and also stderr
echo "Script: $SCRIPTNAME: $MSG" 2>&1
# send same string to logger which puts it in syslog
logger "Script: $SCRIPTNAME: $MSG"

# Now we should be able to check and make sure these scripts are firing more effectively.
exit 0
