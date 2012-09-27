#!/bin/bash
ulimit -f 10240
ulimit -l 0
ulimit -u 128
UMLBOX_PATH="$HOME/bin:/usr/bin:/bin"
BOTHOME=/home/rolebot
CMD="$1"
shift
exec env PATH="$UMLBOX_PATH" USER=rolebot HOME="$BOTHOME" bash -lc "
if [ -f $BOTHOME/.env ]; then source $BOTHOME/.env; fi;
$CMD
/magic/store_env.sh '$BOTHOME/.env' " "$@"