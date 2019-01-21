#!/bin/bash
#
# Check disk and memory usage (using a daily cronjob).
#
# Upon error, notify. Read sys.cron for more details.
#
THE_DIR=/home/homeuser

m_usage=0
m_prcnt=0

d_usage=0
d_prcnt=0

memory () {
	m_usage=`free -b -o | awk 'NR == 2 { print $3 }'`
	[ -z "$m_usage" ] && m_usage=0 && return 1 # Error
	m_prcnt=`free -b -o | awk 'NR > 1 {
		if ($1 == "Mem:") {
			if ($2 > 0) {
				t = $3 / $2
				m = t * 100
			} else {
				m = 0
			}
		}
	} END { print m }'`
	[ -z "$m_prcnt" ] && m_prcnt=0 && return 1 # Error
	return 0
}

disk () {
	
	d_usage=`df -k --total / | tail -1 | awk '{ print $3 }'`
	[ -z "$d_usage" ] && d_usage=0 && return 1 # Error
	# Get the percentage.
	s=`df -k --total / | tail -1 | awk '{ print $5 }'`
	[ -z "$s" ] && return 1 # Error.
	# Remove '%' symbol.
	d_prcnt=${s%\%}
	[ -z "$d_prcnt" ] && d_prcnt=0 && return 1 # Error
	return 0
}

check () {
	r=`expr $1 \> $2`
	return $r
}

# Log
memory; disk
echo "d $d_usage ($d_prcnt%) m $m_usage ($m_prcnt%)" >> $THE_DIR/sys.log

[ $# -eq 0 ] && exit 0 # Notifications disabled.

[ $# -ne 3 ] && exit 1 # Bad number of arguments.

[ -z "$1" ] && exit 1
[ -z "$2" ] && exit 1
[ -z "$3" ] && exit 1 # $1 $2 and $3 are set.

limit=$1
[ -n "`echo $limit | tr -d '[0-9]'`" && exit 1 # Not a numeric value.

username=$2
service=$3

# Notify, once; make sure the router is running.
if [ ! -e $THE_DIR/.NOTIFY -a ! -e $THE_DIR/.STOP ]; then
	
	check $d_prcnt $limit
	a=$?
	check $m_prcnt $limit
	b=$?
	if [ $a -eq 1 -o $b -eq 1 ]; then
	
	id="sys-`date +%Y%m%d%H%M%S`"
	printf \
	"insert into NotificationRequest values (\"%s\",\"%s\",\"%s\",\"%s\")\n" \
	$id \
	$username \
	$service \
	"High system utilization." > logf

	# Disable further notifications until reboot.
	touch $THE_DIR/.NOTIFY
	
	fi # over the limit.
fi

exit 0

