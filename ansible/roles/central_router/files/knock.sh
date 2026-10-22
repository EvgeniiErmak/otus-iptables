#!/usr/bin/env bash
# Port knocking client
# Использование: knock.sh <host> <port1> [port2 ...]
# Пример:        knock.sh 192.168.255.1 8881 7777 9991 && ssh vagrant@192.168.255.1
HOST=$1
shift
for ARG in "$@"; do
  nmap -Pn --host-timeout 100 --max-retries 0 -p "$ARG" "$HOST" >/dev/null
done
