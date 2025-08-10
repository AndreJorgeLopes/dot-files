#!/bin/bash

sleep 2

if [ -n "$DISPLAY" ]; then
  xkbcomp -w 0 ./xkbmap $DISPLAY
  echo "CapsFix ran at $(date)" >>/tmp/capsfix.log
fi
