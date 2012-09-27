#!/bin/bash
cd "$PWD/Plugins/Sandbox/home"
git add -A '*'
git commit -m "$1" --author "$2 <kallisti@spirity.org>"