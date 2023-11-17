#!/bin/bash

if [ -n "$TZ" ]; then
  entrypoint_log "TZ: set timezone to $TZ"
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
  echo $TZ > /etc/timezone
fi
