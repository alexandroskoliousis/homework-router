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
[ -e $HOSTAPD_CONFIG_FILE ] && rm $HOSTAPD_CONFIG_FILE

[ -e /etc/default/hostapd ] && rm /etc/default/hostapd
echo "DAEMON_CONF=\"${HOSTAPD_CONFIG_FILE}\"" > /etc/default/hostapd

# check
if [ -z "${HWR_WIRELESS_SECURITY_TYPE}" ]; then
	echo "error: wireless password type unspecified"
	exit 1
fi
case "${HWR_WIRELESS_SECURITY_TYPE}" in
"wpa")
;;
"wep")
case "${HWR_WIRELESS_PASSWORD_TYPE}" in
"hex")
if [ \
${#HWR_WIRELESS_PASSWORD} != 10 -a \
${#HWR_WIRELESS_PASSWORD} != 26 ]; \
then
	echo "error: hex password is neither 10 nor 26 digits"
	exit 1
fi
;;
"txt")
if [ \
${#HWR_WIRELESS_PASSWORD} !=  5 -a \
${#HWR_WIRELESS_PASSWORD} != 13 ]; \
then
	echo "error: txt password is neither 5 nor 13 digits"
	exit 1
fi
;;
*)
echo "error: wireless password type is neither hex nor txt"
exit 1
;;
esac # wireless password type
;;
*)
echo "error: wireless security type is neither wep nor wpa"
exit 1
;;
esac # wireless security type

(
	echo "interface=${WLESS_IF}"
	echo "bridge=${BRIDGE}"
	echo "driver=nl80211"
	echo "logger_syslog=-1"
	echo "logger_syslog_level=2"
	echo "logger_stdout=-1"
	echo "logger_stdout_level=2"
	echo "debug=0"
	echo "dump_file=/tmp/hostapd.dump"
	echo "ctrl_interface=/var/run/hostapd"
	echo "ctrl_interface_group=0"
	echo "ssid=${HWR_WIRELESS_NAME}"
	echo "hw_mode=g"
	if [ ${HWR_WIRELESS_MODE} == "n" ]; then
		echo "ieee80211n=1"
	fi
	echo "channel=${HWR_WIRELESS_CHANNEL}"
	echo "beacon_int=100"
	echo "dtim_period=2"
	echo "max_num_sta=255"
	echo "rts_threshold=2347"
	echo "fragm_threshold=2346"
	echo "macaddr_acl=0"
	echo "auth_algs=3"
	echo "ignore_broadcast_ssid=0"
	echo "wme_enabled=0"
	echo "wme_ac_bk_cwmin=4"
	echo "wme_ac_bk_cwmax=10"
	echo "wme_ac_bk_aifs=7"
	echo "wme_ac_bk_txop_limit=0"
	echo "wme_ac_bk_acm=0"
	echo "wme_ac_be_aifs=3"
	echo "wme_ac_be_cwmin=4"
	echo "wme_ac_be_cwmax=10"
	echo "wme_ac_be_txop_limit=0"
	echo "wme_ac_be_acm=0"
	echo "wme_ac_vi_aifs=2"
	echo "wme_ac_vi_cwmin=3"
	echo "wme_ac_vi_cwmax=4"
	echo "wme_ac_vi_txop_limit=94"
	echo "wme_ac_vi_acm=0"
	echo "wme_ac_vo_aifs=2"
	echo "wme_ac_vo_cwmin=2"
	echo "wme_ac_vo_cwmax=3"
	echo "wme_ac_vo_txop_limit=47"
	echo "wme_ac_vo_acm=0"
	echo "eapol_key_index_workaround=0"
	echo "eap_server=0"
	echo "own_ip_addr=127.0.0.1"
	case "${HWR_WIRELESS_SECURITY_TYPE}" in
	"wpa")
	echo "wpa=3"
	echo "wpa_passphrase=${HWR_WIRELESS_PASSWORD}"
	echo "wpa_key_mgmt=WPA-PSK"
	echo "wpa_pairwise=CCMP"
	;;
	"wep")
	echo "wep_default_key=0"
	case "${HWR_WIRELESS_PASSWORD_TYPE}" in
	"hex")
	echo "wep_key0=${HWR_WIRELESS_PASSWORD}"
	;;
	"txt")
	echo "wep_key0=\"${HWR_WIRELESS_PASSWORD}\""
	;;
	esac # wireless password type
	;;
	esac # wireless security type

) >> $HOSTAPD_CONFIG_FILE
exit 0

