#!/usr/bin/env bash

# Rootless Support
if ! whoami &> /dev/null
then
  if [ -w /etc/passwd ]
  then
    sed '/^dapagent/d' /etc/passwd > /tmp/passwd
    cat /tmp/passwd > /etc/passwd
    rm -f /tmp/passwd
    echo "dapagent:x:$(id -u):0:dapagent:/home/dapagent:/bin/bash" >> /etc/passwd
    echo "dapagent:x:$(id -u):" >> /etc/group
  fi
fi
USER=$(whoami)
START_ID=$(( $(id -u)+1 ))
echo "${USER}:${START_ID}:2147483646" > /etc/subuid
echo "${USER}:${START_ID}:2147483646" > /etc/subgid

exec "$@"