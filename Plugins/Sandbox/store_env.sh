#!/bin/bash
F=$1
declare -pf > $F
declare -px | grep -vP '^declare -x (SHLVL|PWD|OLDPWD)' >> $F