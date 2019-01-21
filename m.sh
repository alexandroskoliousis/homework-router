#!/bin/bash

# Include functions
. ./f.sh

f1 () { # item 1: proxy
proxy
}

f2 () { # item 2: apt-get
sudo bash -c ". ./c.sh; hwr_conf_user" # otherwise, prompt for passwork on every package
apt
}

f3 () { # item 3: hwdb
hwdb
}

f4 () { # item 4: homework.git
homework
}

f5 () { # item 5: klogger
klogger
}

f6 () { # item 6: ponder
pe
}

f7 () { # item 7: conf
MSG=`sudo bash -c ". ./c.sh; sys -v"`
[ "$MSG" != "OK" ] && RES=1
}

explain () {
clear
echo "
MENU               EXPLANATION
(0) exit           : aborts this program
(1) proxy          : configures proxy settings
(2) apt-get        : installs dependencies (cf. homework.packages)
(3) hwdb           : installs hwdb
(4) homework.git   : installs homework.git submodules
(5) klogger        : installs hwdb's klogger
(6) pe             : installs policy engine
(7) conf           : initializes the router
(?) help           : prints this message"
read -p "Press any key" -n 1
}

ask () {
	n=$1
	echo -n "> "
	while true; do
		read a
		case $a in
		[0-9])
		if [ $a -ge 0 -a $a -le $n ]; then
		return $a
		else 
		echo -n "Ivalid option $a. Choose [0-$n]: "	
		fi
		;;
		"?")
		return $a
		;;
		*) 
		echo -n "Ivalid option $a. Choose [0-$n]: "
		;;
		esac
	done
}

RES=
MSG=

#
# main
#

while true; do

clear

if [ -n "$RES" -a -n "$MSG" ]; then
	if [ $RES -eq 0 ]; then
		echo "OK"
	else
		echo "Error: $MSG"
	fi
else
	echo ""
fi

echo -n "MENU
(0) exit
(1) proxy
(2) apt-get
(3) hwdb
(4) homework.git
(5) klogger
(6) pe
(7) conf
(?) help
"
ask 7
item=$?
RES=
MSG=
if [ $item -eq 0 ]; then
	echo "Bye."
	break
else
	case $a in
	1) f1;;
	2) f2;;
	3) f3;;
	4) f4;;
	5) f5;;
	6) f6;;
	7) f7;;
	"?")
	explain
	;;
	esac
fi

done # outer while loop

exit 0

