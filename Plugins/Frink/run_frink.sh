#!/bin/bash
ulimit -t "$1"
ulimit -m "$2"
frink -e "$3"