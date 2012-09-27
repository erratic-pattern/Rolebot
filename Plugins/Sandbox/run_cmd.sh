#!/bin/bash
cd Plugins/Sandbox
BOTHOME=/home/rolebot
exec nice -n10 /usr/bin/umlbox -n -B -T 10 -m 256000000 -f /etc -t /magic . -f /var -tw $BOTHOME home -t $BOTHOME/.git .git  -t $BOTHOME/logs /home/irclog/logs --cwd $BOTHOME /magic/cmd_wrapper.sh "$@"