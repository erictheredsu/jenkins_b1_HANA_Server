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
	######################### Preparing the environment variables
	###################################################################################################################################################################
	# dev SLD, Server, XApp, B1AH
	ALL_FEATURES_dev=B1ServerToolsSLD,B1ServerToolsMailer,B1ServerToolsLicense,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration

	# 9.1 SLD, Server, XApp, B1AH
	ALL_FEATURES_91=B1ServerToolsSLD,B1ServerToolsMailer,B1ServerToolsExtensionManager,B1ServerToolsLicense,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1ServiceLayerComponent,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration

	# 9.01 SLD, Server, XApp, B1AH
	ALL_FEATURES_90=B1ServerToolsSLD,B1ServerToolsMailer,B1ServerToolsLicense,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration

	# dev SLD, Server
	BASE_FEATURES_dev=B1ServerToolsSLD,B1ServerToolsMailer,B1ServerToolsLicense,B1ServerSHR,B1ServerCommonDB

	# 9.1 SLD, Server
	BASE_FEATURES_91=B1ServerToolsSLD,B1ServerToolsMailer,B1ServerToolsExtensionManager,B1ServerToolsLicense,B1ServerSHR,B1ServerCommonDB,B1ServiceLayerComponent

	# 9.01 SLD, Server
	BASE_FEATURES_90=B1ServerToolsSLD,B1ServerToolsMailer,B1ServerToolsLicense,B1ServerSHR,B1ServerCommonDB
	
	# XApp, B1AH
	XA_FEATURES=B1ServerToolsXApp,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration
	######################### Temp folders and constant files
	INSTALL_BIN_PATH="$BUILD_PATH/$INSTALLER_PKG_NAME/ServerComponents/"
	if [ -z ${CASE_PROP} ]; then
		CASE_PROP="${TOOLS_HOME}/artifacts/scripts/install.properties"
	fi
	if [ ! -d ${WORKSPACE}/${BUILD_NUMBER} ]; then
		mkdir -p ${WORKSPACE}/${BUILD_NUMBER}
	fi
	INSTALL_PROP_PATH="${WORKSPACE}/${BUILD_NUMBER}/${CASE_PROP##*/}"
	cp -f "${CASE_PROP}" "${INSTALL_PROP_PATH}"

	ADDR=${HDB_HOST}
	if [ "${INSTALL_WITH_HOSTNAME}" == "true" ]; then
		ADDR=$(hostname)
	fi
	if [ `echo ${BRANCH} | grep "9.01"` ]; then
		ALL_FEATURES=${ALL_FEATURES_90}
		BASE_FEATURES=${BASE_FEATURES_90}
	elif [ `echo ${BRANCH} | grep "dev"` ]; then
		ALL_FEATURES=${ALL_FEATURES_dev}
		BASE_FEATURES=${BASE_FEATURES_dev}		
		sed -i "/^SL_LICENSE_SERVER=/d" "${INSTALL_PROP_PATH}"
		sed -i "/^SL_LICENSE_SERVER_PORT=/d" "${INSTALL_PROP_PATH}"
	else
		ALL_FEATURES=${ALL_FEATURES_91}
		BASE_FEATURES=${BASE_FEATURES_91}
	fi
	
	sed -i --expression="s/%ADDR%/${ADDR}/g" "${INSTALL_PROP_PATH}"
	sed -i --expression="s/%INSNUM%/$HDB_INST/g" "${INSTALL_PROP_PATH}"
	sed -i --expression="s/%USER%/$HDB_USR/g" "${INSTALL_PROP_PATH}"
	sed -i --expression="s/%PWD%/$HDB_PWD/g" "${INSTALL_PROP_PATH}"


	FEATURES="${INSTALL_TYPE}_FEATURES"
	sed -i --expression="s/%FEATURES%/${!FEATURES}/g" "${INSTALL_PROP_PATH}" 
	###################################################################################################################################################################
	######################### Installing 
	###################################################################################################################################################################
	pushd "$INSTALL_BIN_PATH"
	installer=$(ls -d $PWD/install*)
	chmod +x * -R
	popd
	${installer} --debug -i silent -f ${INSTALL_PROP_PATH}
	RESULT=$?
	###################################################################################################################################################################
	######################### Checking the installation result
	###################################################################################################################################################################
	if [ $RESULT -ne 0 ]; then
		echo "######################### Installation failed:"$RESULT
		JOB_RESULT=false
	else
		echo "######################### Copy client package to shared folder"

		if [ -f $BUILD_PATH/Client*.zip ]; then
			rm -rf $DFT_INSTALL_DIR/B1_SHF/Client.zip
			cp -f $BUILD_PATH/Client*.zip $DFT_INSTALL_DIR/B1_SHF/Client.zip
			RESULT=$?
		fi
		if [ $NO_CLIENT == "true" ]; then
			echo "######################### No need to copy Client.zip"
			JOB_RESULT=true
		elif [ $RESULT -ne 0 ]; then
			echo "######################### Cannot copy Client.zip to target folder..."
			JOB_RESULT=false
		else
			echo "######################### Installation successful"
			JOB_RESULT=true
		fi
		if [ -d "$BUILD_PATH/Wizard" ]; then
			rm -rf $DFT_INSTALL_DIR/B1_SHF/Wizard
			cp -rf $BUILD_PATH/Wizard $DFT_INSTALL_DIR/B1_SHF
			RESULT=$?
		fi
		if [ $RESULT -ne 0 ]; then
			echo "######################### Cannot copy CLient.zip to target folder..."
			JOB_RESULT=false
		else
			echo "######################### Installation successful"
			JOB_RESULT=true
		fi
		
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

