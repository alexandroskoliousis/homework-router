#!/bin/bash

#
# Every function, if unsuccessful, returns 
# an error message stored in $C_MSG.
#
C_MSG=

hwr_conf_acpi () {

	f="/etc/acpi/events/powerbtn"
	if [ ! -e $f ]; then
		C_MSG="$f not found" # acpi not installed
		return 1
	fi
	
	l=`sed -n '/^action=\/bin\/true$/p' $f` # $f already configured
	if [ -z "$l" ]; then
		cp $f $f.bak
		# disable power button
		sed -i "s/\(^action.*\)/action=\/bin\/true\n/g" $f
	fi

	f="/etc/init/control-alt-delete.conf"
	# $f exists by default
	l=`sed -n '/^exec \/bin\/true$/p' $f` # $f already configured
	if [ -z "$l" ]; then
		cp $f $f.bak
		# disable ctrl-alt-del
		sed -i "s/\(^exec.*\)/exec \/bin\/true\n/g" $f
	fi
	# Restart acpi
	service acpid restart &>/dev/null
	return $?
}

#
# A hack.
#
hwr_conf_host () {

	n=`hostname`
	sed -i \
		"s/\(^127.0.0.1\tlocalhost$\)/127.0.0.1\tlocalhost ${n}/g" \
		/etc/hosts
	return 0
}

#
# User 'homeuser' becomes a sudoer.
#
hwr_conf_user () {

	[ -e /etc/sudoers.d/homework ] && return 0

	echo "homeuser ALL=(ALL) NOPASSWD: ALL" > homework.sudoer
	mv homework.sudoer /etc/sudoers.d/homework
	chmod 0440 /etc/sudoers.d/homework
	return $?
}

#
# User 'homeuser' automatically starts the homework router.
#
hwr_conf_bash () {

l=`sed -n '/^# Homework$/p' $HOME/.bashrc`
if [ -z "$l" ]; then
	(
	echo ""
	echo "# Homework"
	echo ". ~/.hwrc"
	) >> $HOME/.bashrc
fi

[ -e $HOME/.hwrc ] && return 0

touch $HOME/.hwrc
java=`update-java-alternatives -l java-6-openjdk | \
	awk '{print $3}'`
# populate .hwrc
(
echo "
export JAVA_HOME=${java}

HWR_AUTO=1
if [ \$(tty) = \"/dev/tty1\" ]; then
	clear
	if [ \$HWR_AUTO -eq 1 ]; then
		sudo ./sysmngr
	else
		echo \"To start, type sudo ./sysmngr\"
	fi
fi"
) > $HOME/.hwrc
return 0
}

#
# Autostart for hostapd, dnsmasq, and tomcat6 daemons is disabled.
#
hwr_conf_init () {
	
	t=`which rcconf`
	[ -z $t ] && C_MSG="rcconf not found" && return 1
	
	[ ! -e /etc/init.d/hostapd ] && C_MSG="hostapd not installed" && \
	return 1
	/etc/init.d/hostapd stop &>/dev/null

	[ ! -e /etc/init.d/dnsmasq ] && C_MSG="dnsmasq not installed" && \
	return 1
	/etc/init.d/dnsmasq stop &>/dev/null
	
	[ ! -e /etc/init.d/tomcat6 ] && C_MSG="tomcat6 not installed" && \
	return 1
	/etc/init.d/tomcat6 stop &>/dev/null

	rcconf --off tomcat6,dnsmasq,hostapd &> /dev/null
	return 0
}

#
# User 'homeuser' autologins.
#
hwr_conf_tty1 () {

	f="/etc/init/tty1.conf"
	# $f exists by default

	l=`sed -n '/^exec \/sbin\/getty -8 38400 tty1$/p' $f`
	[ -z "$l" ] && return 0

	cp -f $f $f.bak
	p="exec \/bin\/login -f homeuser < \/dev\/tty1 > \/dev\/tty1 2>\&1"
	sed -i "s/\(^exec.*\)/$p/g" $f
	return 0
}

hwr_conf_hwr () {
	
	t=`which rcconf`
	[ -z $t ] && C_MSG="mysql not found" && return 1
	
	[ ! -e "MySQL.conf" ] && \
	C_MSG="MySQL.conf not found" && return 1
	[ "$1" != "-v" ] && echo "You've entered the realm of MySQL (as root)."
	mysql -u root -p < MySQL.conf
	
	[ ! -e homework.conf ] && \
	C_MSG="homework.conf not found" && return 1
	
	[ -r "homework.conf" ] && . homework.conf
	# clear previous run
	[ -e "homework.sql" ] && rm -f homework.sql
	
	[ -n "$HWR_ASSIGNS" ] && \
	(
	while IFS=';' read -ra pairs; do # read HWR_ASSIGNS
		
		for pair in "${pairs[@]}"; do
		mc=`echo $pair | awk '{split($0, a, "|"); print a[1]}'`
		ip=`echo $pair | awk '{split($0, a, "|"); print a[2]}'`
		# assign $ip to $mc

		echo "INSERT INTO Leases VALUES \
		(\"${mc}\", \"${ip}\", \"NULL\", \"del\") \
		ON DUPLICATE KEY UPDATE \
		macaddr=VALUES(macaddr), ipaddr=VALUES(ipaddr);" >> homework.sql
		
		done

	done <<< "$HWR_ASSIGNS"
	)

	[ -n "$HWR_HOUSEHOLD_ALLOWANCE" ] && \
	(
	v=$(( $HWR_HOUSEHOLD_ALLOWANCE * 1073741824 ))
	
	echo "INSERT INTO Allowances VALUES \
	(\"HOME\", \"${v}\") \
	ON DUPLICATE KEY UPDATE allowance=VALUES(allowance);"
	) >> homework.sql
	
	[ -s homework.sql ] && \
	mysql -u homeuser -phomework -D Homework < homework.sql
	rm -f homework.sql
	
	return 0
}

hwr_conf_udev () {
	return 0
}

#
# Configure system.
#
sys () {

	hwr_conf_acpi && \
	hwr_conf_init && \
	hwr_conf_udev && \
	hwr_conf_host && \
	hwr_conf_user && \
	hwr_conf_bash && \
	hwr_conf_tty1
	
	#
	# -v returns the error message to the caller that standard output
	#
	if [ $? -ne 0 ]; then
		[ "$1" == "-v" ] && echo "$C_MSG"
		return 1
	fi

	hwr_conf_hwr $1
	if [ $? -ne 0 ]; then
		[ "$1" == "-v" ] && echo "$C_MSG"
		return 1
	fi

	[ "$1" == "-v" ] && echo "OK"
	C_MSG="OK"
	return 0
}

#
# Run this file as a stand-alone program as ./c.sh -e
#
if [ $# -eq 1 ]; then
	if [ $1 = "-e" ]; then
		sys 
		[ "$C_MSG" != "OK" ] && echo "Error: $C_MSG" || echo "$C_MSG"
		exit 0
	fi
fi

