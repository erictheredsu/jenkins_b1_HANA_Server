#!/bin/bash
#
#	install SLD, XApp, SBOCOMMON and B1AH
#

# import the libs
. ${0%/*}/lib_core.sh


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
#HDB_USR=SYSTEM
#HDB_PWD=manager
#SBOTESTUS
#SBOTESTCN
#SBOTESTDE
#SLAVE_WIN32
#ARCHIVE_RESULT
#BUILD_PATH


function install() {
	###################################################################################################################################################################
	######################### Installing 
	###################################################################################################################################################################
	INSTALL_BIN_PATH="$BUILD_PATH/$INSTALLER_PKG_NAME/ServerComponents/"
	chmod -R +x "$INSTALL_BIN_PATH" 
	pushd "$INSTALL_BIN_PATH"
	bash -x install.bin --debug -i silent -f "$CASE_PROP"
	RESULT=$?
	popd
	if [ $RESULT -ne 0 ]; then
		echo "######################### Installation failed:"$RESULT
		JOB_RESULT=false
	else
		echo "######################### Copy client package to shared folder"
		if [ ! -d $DFT_INSTALL_DIR/B1_SHF ]; then
			mkdir -p $DFT_INSTALL_DIR/B1_SHF
		fi
		if [ -f " $BUILD_PATH/Client.zip" ]; then
			mv -f $BUILD_PATH/Client.zip $DFT_INSTALL_DIR/B1_SHF
		fi
		if [ -d "$BUILD_PATH/Wizard" ]; then
			mv -f $BUILD_PATH/Wizard $DFT_INSTALL_DIR/B1_SHF
		fi
		echo "######################### Installation successful"
		JOB_RESULT=true
	fi
}


#
# entry point
#
function main() {
	install
	qset "JOB_RESULT" "$JOB_RESULT"
}

main

