#!/bin/bash
#
#	archive build
#

# import the libs
. ${0%/*}/lib_core.sh


#
# entry point
#
#BUILDS_POOL=/home/jenkins/buildspace/builds49/
#BUILDS_SHARE_FOLDER=//10.58.6.49/builds_cn/SBO/
#BUILDS_SHARE_FOLDER_DOMAIN=SAP_ALL
#BUILDS_SHARE_FOLDER_USER=TA_admin
#BUILDS_SHARE_FOLDER_PWD=B1tA@VM2010
#DFT_INSTALL_DIR=/opt/sap/SAPBusinessOne
#INSTALLER_PKG_NAME=Packages.Linux
#LOCAL_HOST=10.58.120.166
#LOCAL_HOST_PORT=60000
#LOCAL_HOST_USER=admin
#LOCAL_HOST_PWD=1234
#MNT_PATH=/home/jenkins/buildspace/mnt49
#RAR_HOME=/home/jenkins/tools/rar
#SLAVE_HOME=/home/jenkins
#TOOLS_HOME=/home/jenkins/tools
#HDB_CLIENT=/usr/sap/hdbclient

#HDB_HOST=10.58.121.140
#ROOT_PWD=
#BRANCH=dev
#HDB_INST=00
#HDB_USER=SYSTEM
#HDB_PWD=manager
#SBOTESTUS
#SBOTESTCN
#SBOTESTDE
#SLAVE_WIN32
#ARCHIVE_RESULT
function archive() {
	BRANCH_POOL=${BUILDS_POOL%/}/$BRANCH
	pushd ${BRANCH_POOL}
	prevB=`ls -l prev | awk '{print $11}' | sed "s:$BRANCH_POOL::g"`
	prevB=`echo $prevB | tr -d "//"`
	newB=`ls -l new | awk '{print $11}' | sed "s:$BRANCH_POOL::g" `
	newB=`echo $newB | tr -d "//"`
	if [ -z ${prevB} ]; then
		prevB="prev"
	fi
	if [ -z ${newB} ]; then
		newB="new"
	fi
	fB=`ls | grep -v ${prevB} | grep -v ${newB} | grep -v "new" | grep -v "prev" | grep -v grep`
	if [ ! -z ${fB} ]; then
		rm -rf ${fB}
	fi
	if [ -h prev ]; then
		prev=`ls -l prev | awk '{print $11}'`
	else
		prev=""
	fi
	if [ -h new ]; then
		new=`ls -l new | awk '{print $11}'`
	else
		new=""
	fi
	if [ ! -z "$new" ] && [ "$ARCHIVE_RESULT" == "true" ] && [ "$new" != "$prev" ]; then
	        rm -rf prev
	        ln -s $new prev
			qset "PREV_BUILD_PATH" "$NEW_BUILD_PATH"
	        if [ ! -z "$prev" ] && [ `echo $prev | grep ".HANA"` ]; then
	                rm -rf $prev
	        fi
	elif [ ! -z "$new" ] && [ "$ARCHIVE_RESULT" == "false" ] && [ "$new" != "$prev" ] && [ `echo $new | grep ".HANA"` ]; then
	        rm -rf $new/*
	fi
	rm -rf new
	popd
}
function backupRPM() {
	pushd ${BUILDS_POOL}/${BRANCH}/prev/${INSTALLER_PKG_NAME}/ServerComponents/RPM
	B1A_RPM=`ls B1AnalyticsPlatformCommon-*.rpm`
	XAPP_RPM=`ls B1ServerToolsXApp-*.rpm`
	if [ ! -z ${B1A_RPM} ]; then
		cp -f "${B1A_RPM}" "${B1A_RPM}.bk"
	fi
	if [ ! -z ${XAPP_RPM} ]; then
		cp -f "${XAPP_RPM}" "${XAPP_RPM}.bk"
	fi
	popd
}

function main() {
	archive
	if [ "$ARCHIVE_RESULT" == "true" ]; then
		backupRPM
	fi
}

main

