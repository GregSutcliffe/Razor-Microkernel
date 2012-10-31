#! /bin/sh

CMDLINE=`cat /proc/cmdline`
for x in $CMDLINE
do
  case $x in
    foreman_ip=*)
      FOREMAN_IP="${x//foreman_ip=}"
      ;;
  esac
done
FOREMAN_URL="http://${FOREMAN_IP}/smart_proxies"
NAME=`hostname`
IP=`facter ipaddress`

curl -s -H "Accept:application/json" -k \
  -d "smart_proxy[name]=$NAME" \
  -d "smart_proxy[url]=http://$IP:8443" \
  $FOREMAN_URL

