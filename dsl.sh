#!/bin/bash
#

user=`id -u`
if [ $user != "0" ]; then
	echo "error: this script must be run as root" 1>&2
	exit 1
fi

HWR_CONFIG_FILE="homework.conf"
[ -r "$HWR_CONFIG_FILE" ] && . $HWR_CONFIG_FILE

[ -e $DSL_CHAP_FILE ] && rm $DSL_CHAP_FILE
echo "\"${DSL_ISP_USER}\" * \"${DSL_ISP_PSWD}\"" > $DSL_CHAP_FILE
chmod go-r $DSL_CHAP_FILE

# reset
[ -e $DSL_CONFIG_FILE ] && rm $DSL_CONFIG_FILE

(
	echo "noipdefault"
	echo "defaultroute"
	echo "replacedefaultroute"
	echo "hide-password"
	echo "noauth"
	echo "persist"
	echo "plugin rp-pppoe.so ${GATEWAY}"
	echo "user \"${DSL_ISP_USER}\""
	echo "usepeerdns"

) >> $DSL_CONFIG_FILE
exit 0
