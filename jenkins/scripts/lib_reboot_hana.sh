#!/bin/bash
#
#	reboot HANA instance
#

# import the libs
. ${0%/*}/lib_core.sh

function restartHDB() {
	HDB_INST_OWNER=`ps aux | grep HDB${HDB_INST}/exe/sapstartsrv | grep -v grep | awk '{print $1}' | awk "NR==1"`
	su - $HDB_INST_OWNER -c "./HDB stop"
	su - $HDB_INST_OWNER -c "./HDB start"
	RESULT=$?
	return $RESULT
}

function restartSLD() {
	# restart SLD
	/etc/init.d/sapb1servertools restart
	# restart service layer
	if [ -e /etc/init.d/b1s ]; then
		/etc/init.d/b1s restart
	fi
}

#
# entry point
#
function main() {
	restartHDB
	restartSLD
}

main

