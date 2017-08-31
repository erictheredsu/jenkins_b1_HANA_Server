#!/bin/bash
# all
# base
# xa
# INSTALLER_DIR
function install() {
###################################################################################################################################################################
######################### Preparing the environment variables
###################################################################################################################################################################
######################### Temp folders and constant files
export INSTALL_BIN_PATH="$INSTALLER_DIR/$INSTALLER_PKG_NAME/ServerComponents/"
export INSTALL_PROP_PATH="$INSTALLER_DIR/$INSTALLER_PKG_NAME/ServerComponents/install.properties"
export ALL_FEATURES=B1ServerToolsSLD,B1ServerToolsExtensionManager,B1ServerToolsLicense,B1ServerToolsMailer,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration
export BASE_FEATURES=B1ServerToolsSLD,B1ServerToolsExtensionManager,B1ServerToolsLicense,B1ServerToolsMailer,B1ServerSHR,B1ServerCommonDB
export XA_FEATURES=B1ServerToolsXApp,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration
###################################################################################################################################################################
######################### Installing 
###################################################################################################################################################################
	rm -rf $INSTALL_PROP_PATH
	cp "$WORKSPACE/$BRANCH/jenkins/scripts/install.properties" "$INSTALL_PROP_PATH"
	sed -i --expression="s/%ADDR%/$HANA_SERVER_ADDRESS/g" "$INSTALL_PROP_PATH"
	sed -i --expression="s/%INSNUM%/$HANA_INSTANCE_NUM/g" "$INSTALL_PROP_PATH"
	sed -i --expression="s/%USER%/$HANA_INSTANCE_USER/g" "$INSTALL_PROP_PATH"
	sed -i --expression="s/%PWD%/$HANA_INSTANCE_PWD/g" "$INSTALL_PROP_PATH"
	case "$1" in
        	all)
        	sed -i --expression="s/%FEATURES%/$ALL_FEATURES/g" "$INSTALL_PROP_PATH"
        	;;
        	base)
        	sed -i --expression="s/%FEATURES%/$BASE_FEATURES/g" "$INSTALL_PROP_PATH"
        	;;
        	xa)
        	sed -i --expression="s/%FEATURES%/$XA_FEATURES/g" "$INSTALL_PROP_PATH"
        	;;
        	*)
        	echo "######################### Usage: $0 {all|base|xa}"
        	exit 1
        	;;
	esac
	chmod -R +x "$INSTALL_BIN_PATH" 
	pushd "$INSTALL_BIN_PATH"
	./install.bin --debug -i silent -f install.properties
	RESULT=$?
	popd
	if [ $RESULT -ne 0 ]; then
		echo "######################### Installation failed:"$RESULT
		exit $RESULT
	else
		echo "######################### Copy client package to shared folder"
		cp -f $INSTALLER_DIR/Client*.zip $DFT_INSTALL_DIR/B1_SHF/Client.zip
	fi
	echo "######################### Installation successful"
	exit $RESULT
}