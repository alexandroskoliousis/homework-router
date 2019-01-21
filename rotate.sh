#!/bin/bash
#
HWR_CONFIG_FILE="homework.conf"
[ -r $HWR_CONFIG_FILE ] && . $HWR_CONFIG_FILE
gzip -f -9 $1
rm -f traces.$$
X=`du -b $MON_DIR | awk '{ print $1 }'`
N=`ls $MON_DIR/ | wc -l`
$HWR_VERBOSE && echo "$N files occupy $X bytes"
if [ $X -lt $MON_MAX ]; then
	exit 0
fi
# Else, delete older files.
ls $MON_DIR > traces.$$
while read filename; do
	Y=`du -b $MON_DIR/$filename | awk '{ print $1 }'`
	$HWR_VERBOSE && echo "$MON_DIR/$filename occupies $X bytes"
	rm -f $MON_DIR/$filename
	X=$(( X-Y ))
	$HWR_VERBOSE && echo "X'=$X"
	if [ $X -lt $MON_MAX ]; then
		break
	fi
done < traces.$$
rm -f traces.$$
exit 0
