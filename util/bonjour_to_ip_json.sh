#!/usr/bin/env bash

# Uses ping to resolve a .local mDNS address to IP.
# Input: list of hostnames
# Output: json structure: [ { "<hostname>": "<ip>" }, ...]

printf "["
IPS=$(for h in $@; do
  echo "{\"hostname\": \"$h\""
  echo "\"ip\": \"`ping -q -c 1 -t 1 $h | grep -m 1 PING | cut -d "(" -f2 | cut -d ")" -f1`\"}"
done)
printf "${IPS}" | tr '\n' ','
printf "]"
