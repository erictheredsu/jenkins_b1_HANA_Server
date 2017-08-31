#!/bin/bash
#
#	prepare slave for the first time use
#

# import the libs
. ${0%/*}/lib_core.sh
. ${0%/*}/lib_prepare_syslibs.sh

# function prepareToolsHome() {
# 	echo "############################## prepare the tools home: $TOOLS_HOME"
# 	if [ ! -d $TOOLS_HOME ]; then
# 		mkdir -p $TOOLS_HOME
# 	fi
# 	mount -t cifs -o guest "$JENKINS_SHF" "$TOOLS_HOME"
# }

function prepareHDBClient() {
	if [ ! -d $HDB_CLIENT ]; then
		echo "############################## prepare the HDB client"
		pushd $HDB_CLIENT_INS64
		./hdbinst -b
		RST64=$?
		popd
		if [ $RST64 -ne 0 ]; then
			exit $RST64
		fi
	fi
	if [ ! -d $HDB_CLIENT32 ]; then
		echo "############################## prepare the HDB client"
		pushd $HDB_CLIENT_INS32
		./hdbinst -b
		RST32=$?
		popd
		if [ $RST32 -ne 0 ]; then
			exit $RST32
		fi
	fi
}

function showDiagostic() {
	echo "############################## show diagostic info"
	hostname -f
	ifconfig | grep addr
	cat /etc/*release
	cat /proc/cpuinfo | grep name
	lscpu | grep -E Hyper\|CPU
	cat /proc/meminfo | grep Mem
	df -lh
	echo
}

function mountShF() {
	if [ ! -d "$MNT_PATH" ]; then
	    echo "######################### mount folder does not exist, creating..."
        mkdir -p "$MNT_PATH"
    fi
	BRANCH_PATH=$(ls -d "${MNT_PATH%/}"/$BRANCH | awk "NR==1" | awk '{ print $1 }')
	MOUNTED=`mount | grep ${MNT_PATH%/} | grep ${OLD_BUILDS_SHARE_FOLDER%/} | wc -l`
	if [ ${MOUNTED} -gt 0 ]; then
		echo "######################### umounting the old shared folder..."
		umount -l ${MNT_PATH%/}
	fi
	if [ ! -d "$BRANCH_PATH" ]; then
        echo "######################### Cannot find package, mounting..."
        mount.cifs -o username=$BUILDS_SHARE_FOLDER_USER,password=$BUILDS_SHARE_FOLDER_PWD "$BUILDS_SHARE_FOLDER" "$MNT_PATH"
		BRANCH_PATH=$(ls -d "${MNT_PATH%/}"/$BRANCH | awk "NR==1" | awk '{ print $1 }')
    fi
	if [ ! -d $BRANCH_PATH ]; then
		echo "######################### Cannot find the $BRANCH directory"
		exit 1
	fi
}

#
# entry point
#
function main() {
	showDiagostic
	prepareHDBClient
	prepareSysLibs
	mountShF
}

main

