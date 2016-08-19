#!/bin/bash

set -x

IFACE=${1:-`/sbin/route | grep default | tr ' ' '\n' | tail -1`}
INTERNAL_IP=`sudo ifconfig ${IFACE} 2>/dev/null|awk '/inet addr:/ {print $2}'|sed 's/addr://'`

hyperkube kubectl get nodes -o json \
  | jq -r '.items[] | "\(.spec.podCIDR),\(.status.addresses[] | select(.type == "InternalIP") | .address)"' \
  | grep -v "$INTERNAL_IP" \
  | awk -F, '{printf "route add -net %s gw %s dev '${IFACE}'\n", $1, $2}'
