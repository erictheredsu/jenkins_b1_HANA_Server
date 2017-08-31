#!/bin/bash
#
#	b1 related function
#

function swipe_b1() {
	echo "############################## Kill the httpd process"
	ps aux | grep "ServiceLayer" | grep "httpd" | grep -v  grep | awk '{print $2}' | xargs kill -9
	echo "############################## Find the installed B1"
	ETC_INIT_PATH=/etc/init.d
	B1_LAUNCH_SCRIPT=sapb1servertools
	SL_LAUNCH_SCRIPT=b1s
	B1A_LAUNCH_SCRIPT="b1ad"
	B1_INSTALLED_COMMON_DIR=/opt/sap/SAPBusinessOne/Common
	INSTALLED=false
	if [ ! -f "$ETC_INIT_PATH/$B1_LAUNCH_SCRIPT" ]; then
		if [ ! -d "$B1_INSTALLED_COMMON_DIR" ]; then
			echo "############################## No installed B1 found"
			echo "############################## Try to remove all rpm records whatever"
			rpm -qa | grep B1 | xargs rpm -e --allmatches || :
			return 0
		else
			INSTALL_COMMON_DIR=$B1_INSTALLED_COMMON_DIR
		fi
	else
		INSTALL_COMMON_DIR=`sed -n '/^INSTALL_DIR=/{s/INSTALL_DIR=//p}' "$ETC_INIT_PATH/$B1_LAUNCH_SCRIPT" | sed 's/\n//g' | sed 's/\r//g' | sed 's/\"//g'`
	fi
	INSTALL_DIR="${INSTALL_COMMON_DIR%/Common*}"
	echo "############################## Kill the unified tomcat process"
	TOMCAT_PID=`ps aux | grep "$INSTALL_COMMON_DIR/tomcat" | grep -v grep | awk '{print $2}'`
	if [ ! -z $TOMCAT_PID ] && [ $TOMCAT_PID -gt 0 ]; then
		kill -9 $TOMCAT_PID
	fi
	ps aux | grep ${INSTALL_DIR} |  grep httpd | grep -v grep | awk '{print $2}' | xargs kill -9 || :
	echo "############################## Remove B1 files"
	pushd $ETC_INIT_PATH
	chkconfig -d "$B1_LAUNCH_SCRIPT"
	rm -rf "$ETC_INIT_PATH/$B1_LAUNCH_SCRIPT"
	chkconfig -d "$SL_LAUNCH_SCRIPT"
	rm -rf "$ETC_INIT_PATH/$SL_LAUNCH_SCRIPT"
	rm -rf "$ETC_INIT_PATH/b1s50000"
	rm -rf "$ETC_INIT_PATH/b1s50001"
	rm -rf "$ETC_INIT_PATH/b1s50002"
	rm -rf "$ETC_INIT_PATH/b1s50003"
	echo "############################## Remove rpm records"
	for user in $(cut -d: -f1 /etc/passwd | grep b1service)
	do
		userdel $user
	done
	for group in $(cut -d: -f1 /etc/group | grep b1service)
	do
		groupdel $group
	done
	rpm -qa | grep B1 | xargs rpm -e --allmatches
	rm -rf "$INSTALL_DIR"
	if [ -f "$ETC_INIT_PATH/$B1A_LAUNCH_SCRIPT" ]; then
		echo "############################## B1AH installed by Installanywhere installer is found..."
		INSTALL_B1A_DIR=`sed -n '/^INSTALL_DIR=/{s/INSTALL_DIR=//p}' "$ETC_INIT_PATH/$B1A_LAUNCH_SCRIPT" | sed 's/\n//g' | sed 's/\r//g'`
		echo "############################## Kill the sperated tomcat process"
		TOMCAT_PID=`ps aux | grep "$INSTALL_B1A_DIR/tomcat" | grep -v grep | awk '{print $2}'`
		if [ ! -z $TOMCAT_PID ] && [ $TOMCAT_PID -gt 0 ]; then
			kill -9 $TOMCAT_PID
		fi
		echo "############################## Remove installed B1A files"
		pushd $ETC_INIT_PATH
		chkconfig -d "$B1A_LAUNCH_SCRIPT"
		rm -rf "$ETC_INIT_PATH/$B1A_LAUNCH_SCRIPT"
		rm -rf "/root/Change_B1A_Installation"
		rm -rf "/var/.com.zerog.registry.xml"
	fi
	popd
	return 0
}
