#!/bin/bash
#
#	cleanup b1ah
#

# import the libs
. ${0%/*}/lib_core.sh

function cleanupb1ah() {
	echo "############################## Find the installed B1"
	ETC_INIT_PATH=/etc/init.d
	B1_LAUNCH_SCRIPT=sapb1servertools
	B1_INSTALLED_TOMCAT_DIR=/opt/sap/SAPBusinessOne/Common
	INSTALLED=false
	if [ ! -f "$ETC_INIT_PATH/$B1_LAUNCH_SCRIPT" ]; then
		if [ ! -d "$B1_INSTALLED_COMMON_DIR" ]; then
			echo "############################## No installed B1 found"
			#qset "JOB_RESULT" "false"
			#return 1
			return 0
		else
			INSTALL_COMMON_DIR=$B1_INSTALLED_COMMON_DIR
		fi
	else
		INSTALL_COMMON_DIR=`sed -n '/^INSTALL_DIR=/{s/INSTALL_DIR=//p}' "$ETC_INIT_PATH/$B1_LAUNCH_SCRIPT" | sed 's/\n//g' | sed 's/\r//g' | sed 's/\"//g'`
	fi
	INSTALL_DIR="${INSTALL_COMMON_DIR%/Common*}"
	rpm -qa | grep -E B1Analytics\|XApp | xargs rpm -e
	rm -rf "$INSTALL_DIR/Common/tomcat/conf/Catalina/localhost/IMCC.xml"
	rm -rf "$INSTALL_DIR/Common/tomcat/conf/Catalina/localhost/Enablement.xml"
	rm -rf "$INSTALL_DIR/Common/tomcat/webapps/IMCC"
	rm -rf "$INSTALL_DIR/Common/tomcat/webapps/Enablement"
	rm -rf "$INSTALL_DIR/AnalyticsPlatform"
}
#
# entry point
#
function main() {
	cleanupb1ah
}

main

