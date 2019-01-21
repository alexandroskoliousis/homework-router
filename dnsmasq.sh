#!/bin/bash
#

user=`id -u`
if [ $user != "0" ]; then
	echo "error: this script must be run as root" 1>&2
	exit 1
fi

HWR_CONFIG_FILE="homework.conf"
[ -r "$HWR_CONFIG_FILE" ] && . $HWR_CONFIG_FILE

# reset
[ -e $DNSMASQ_CONFIG_FILE ] && rm $DNSMASQ_CONFIG_FILE

subnet=${GATEWAY_ADDRESS%.*}
machine=`hostname`

[ -e /etc/homeworkhost ] && rm /etc/homeworkhost
[ -n "${machine}" ] && \
echo -e "${GATEWAY_ADDRESS}\t${machine}" > /etc/homeworkhost

if [ -n $1 ]; then
	if [ "$1" == "fail-safe" ]; then
		$HWR_VERBOSE && echo "In fail-safe mode, dnsmasq runs DNS/DHCP."
		NOX_ENABLED=false
	fi
fi

! $NOX_ENABLED && [ ! -x /bin/dhcplogger ] \
echo "warning: dhcplogger is not installed"

(
	echo "domain-needed"
	echo "bogus-priv"
	echo "no-hosts"
	[ -e /etc/homeworkhost ] && \
	echo "addn-hosts=/etc/homeworkhost"

	echo "interface=${BRIDGE}" # Listen for DNS and DHCP requests
	case "${HWR_CONNECTION_TYPE}" in
	"pppoe")
	echo "except-interface=${PPPOE}"
	;;
	"cable" | "mpoa")
	echo "except-interface=${GATEWAY}"
	;;
	esac
	
	if $NOX_ENABLED; then
		# disable DHCP server
		echo "no-dhcp-interface=${BRIDGE}"
	else
	
	echo "dhcp-range=\
${subnet}.${DNSMASQ_IPRANGE_START},\
${subnet}.${DNSMASQ_IPRANGE_UNTIL},\
${DNSMASQ_LEASE_DURATION}h"
	
	echo "dhcp-authoritative"
	
	[ -x "/bin/dhcplogger" ] && \
	echo "dhcp-script=/bin/dhcplogger"
	
	# echo "log-queries"
	echo "log-dhcp"
	
	fi # NOX_ENABLED

) >> $DNSMASQ_CONFIG_FILE
exit 0
