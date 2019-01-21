#!/bin/bash

#
# Selected gateway
#
gw=""

ip () { # Does $1 have an IP?
	[ -z "$1" ] && return 1
	s=`ifconfig $1 2> /dev/null | awk '$1=="inet" {print $2}'`
	if [ -n "$s" ]; then
		a=`echo $s | awk '{split($0, t, ":"); print t[2]}'`
		[ -n "$a" ] && return 0 # IP found
	fi
	return 1
}

connect () {
	if [ -n "$gw" ]; then # Previously selected gateway.
		ip $gw
		[ $? -eq 0 ] && return 0
	fi
	interfaces=`ifconfig -a -s | awk ' NR>1 {print $1}'`
	interfaces=`echo $interfaces | sed 's/lo//g'`
	s=""
	for i in $interfaces; do 
		[ -z "$s" ] && s="$i" || s="${s}, ${i}"
	done
	s="["${s}"]"
	echo -n "Select a gateway $s: "
	read gw
	[ -z $gw ] && MSG="invalid interface" && return 1
	ifconfig -a -s | grep $gw > /dev/null
	[ $? -ne 0 ] && MSG="invalid interface ${gw}" && return 1
	ip $gw && return 0
	# 
	# How to spoof a MAC address (e.g. 00:50:b6:03:23:0b)
	#
	# sudo ifconfig $gw down
	# sudo ifconfig $gw hw ether "00:50:b6:03:23:0b"
	#
	sudo ifconfig $gw up
	echo -n "connecting..."
	sudo dhclient $gw &>/dev/null
	! ip $gw && echo "failed" && MSG="connection failure" && return 1
	echo "OK"
	return 0
}

#
# Install NOX
#
nox () {
	t=`pwd`
	cd homework/nox.git
	git checkout nox-v2-deployment
	./boot.sh
	[ ! -d build ] && mkdir build
	cd build && ../configure
	make -j4 ; make
	cd src && make check
	cd $t
	return 0
}

#
# Install openvswitch
#
openvswitch () {
	t=`pwd`
	cd homework/openvswitch.git
	./boot.sh
	./configure --with-l26=/lib/modules/`uname -r`/build
	make -j4 ; make
	sudo make install
	cd $t
	return 0
}

#
# Install homework-devices (aka control panel)
#
control () {
	t=`pwd`
	cd homework/homework-devices.git
	git checkout master
	sudo ant install
	# [ -d /var/lib/tomcat6/webapps/control ] && sudo rm -rf /var/lib/tomcat6/webapps/control
	# sudo cp build/control.war /var/lib/tomcat6/webapps/
	# sudo chmod 755 /var/lib/tomcat6/webapps/control.war
	cd $t
	return 0
}

#
# Install homework-notify-server
#
notifications () {
	t=`pwd`
	cd homework/homework-notify-server.git
	git checkout master
	cd notifications/
	CP=".:$t/java-libs/gson-1.7.1.jar:$t/java-libs/jsrpc.jar:/usr/share/java/mysql.jar"
	javac -classpath $CP *.java
	cd $t
}

#
# Fetch modules from git://github.com/homework/homework.git.
#
homework () {
	t=`which git`
	[ -z $t ] && RES=1 && MSG="git not found" && return 0
	! connect && RES=1 && return 0 # MSG set by connect()
	t=`pwd`
	git clone git://github.com/homework/homework.git
	[ ! -d homework ] && \
	MSG="git clone homework.git failed" && return 0
	cd homework/
	git submodule init && git submodule update
	cd $t
	openvswitch && nox && control && notifications
	return 0
}

#
# Install the policy engine
#
pe () {

	ant=`ant -version`
	[ $? -ne 0 ] && MSG="ant not found" && return 1

	[ -e pe.tar.gz ] && rm -f pe.tar.gz
	echo -n "Fetching pe.tar.gz..."
	wget http://www.doc.ic.ac.uk/~dpediadi/files/pe.tar.gz &>/dev/null
	if [ ! -e pe.tar.gz ]; then
		MSG="failed to fetch www.doc.ic.ac.uk/~dpediadi/files/pe.tar.gz"
		return 1
	fi
	echo "OK"

	tar -xzf pe.tar.gz
	rm pe.tar.gz

	[ ! -d "pe" ] && MSG="pe/ not found" && return 1

	MSG="OK" && RES=0
	return 0
}

#
# Install the homework database
#
hwdb () {
	
	[ -e hwdb.tar ] && rm -f hwdb.tar

	[ -d hwdb ] && rm -rf hwdb/

	echo -n "Fetching hwdb.tar..."
	wget http://www.dcs.gla.ac.uk/~koliousa/hwdb.tar &>/dev/null
	if [ ! -e hwdb.tar ]; then
		MSG="failed to fetch www.dcs.gla.ac.uk/~koliousa/hwdb.tar"
		return 1
	fi
	echo "OK"
	
	mkdir hwdb
	mv hwdb.tar hwdb/
	cd hwdb/
	tar -xf hwdb.tar
	./genmakefile.sh
	make
	sudo make install
	cd ..
	MSG="OK" && RES=0
	return 0
}

klogger () {
	t=`pwd`
	cd $HOME/hwdb/kernel/
	sudo ./klog make ovs $HOME/homework/openvswitch.git silent
	cd $t
	MSG="OK" && RES=0
}

#
# Set proxy settings; used by apt-get, and wget.
#
proxy () {

	[ -e "/etc/apt/apt.conf" ] && sudo rm -f /etc/apt/apt.conf

	[ -e "$HOME/.wgetrc" ] && rm /home/homeuser/.wgetrc

	echo -n "Enter HTTP proxy (e.g. http://wwwcache.dcs.gla.ac.uk:8080): "
	read s

	if [ -n "$s" ]; then
		
		# Check proxy pattern
		
		sudo sh -c \
		"echo 'Acquire::http::proxy \"${s}\";' > /etc/apt/apt.conf"
		
		[ $? -ne 0] && \
		RES=1 && MSG="failed to configure proxy for apt" && \
		return 1
		
		echo "http_proxy=${s}" > $HOME/.wgetrc
		
		[ $? -ne 0] && \
		RES=1 && MSG="failed to configure proxy for wget" && \
		return 1
		
		# If we reach this point, proxy was set correctly.
		MSG="OK"
		RES=0
	else
		MSG="no proxy specified"
		RES=1
	fi
	return 0
}

#
# Install depedencies
#
apt () {
	
	! connect && RES=1 && return 0 # MSG set by connect()

	# (re)synchronize package index files
	echo -e -n "\rUpdating packages..."
	sudo apt-get update &> /dev/null

	dpkg -s network-manager &>/dev/null
	[ $? -eq 0 ] && apt-get purge --assume-yes network-manager
	
	l=`wc -l homework.packages | awk '{ print $1 }'`
	c=0
	while read pkg; do
		let c++
		p=$(( 100 * $c / $l ))
		printf "\r%80s" ""
		printf "\r%s/%s (%s%%) %s " $c $l $p ${pkg}
		dpkg -s ${pkg} &>/dev/null
		[ $? -eq 0 ] && continue
		sudo apt-get -y -q --allow-unauthenticated install "$pkg" # &>/dev/null
		# $pkg installed?
		dpkg -s ${pkg} &>/dev/null
		if [ $? -eq 1 ]; then
			MSG="failed to install ${pkg}"
			RES=1
			break
		fi
	done < homework.packages

	MSG="OK" && RES=0
	return 0
}

