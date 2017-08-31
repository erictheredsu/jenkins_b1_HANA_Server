#!/bin/bash
######################### Usage:
######################### 
###################################################################################################################################################################
######################### Preparing the environment variables
###################################################################################################################################################################
######################### Tools preparation
if [ ! -d $RAR_HOME ]; then
	echo "Cannot find rar tool for extracting package..."
	exit 1
fi
export PATH=$RAR_HOME:$PATH
######################### Temp folders and constant files
export JENKINS_TA_TEMP_DIR=/tmp/TA_$BUILD_NUMBER
export MNT_PATH="$JENKINS_TA_TEMP_DIR/$BRANCH"
export INSTALLER_PKG_NAME="Packages.Linux"
export INSTALL_BIN_PATH="$JENKINS_TA_TEMP_DIR/$INSTALLER_PKG_NAME/ServerComponents/"
export INSTALL_PROP_PATH="$JENKINS_TA_TEMP_DIR/$INSTALLER_PKG_NAME/ServerComponents/install.properties"
export ALL_FEATURES=B1ServerToolsSLD,B1ServerToolsExtensionManager,B1ServerToolsLicense,B1ServerToolsMailer,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration

######################### Build package shared folder
export BUILD_PATH="//10.58.6.49/builds_cn/SBO/$BRANCH"

######################### Package
PKG_PATH=""
CLIENT_PATH=""

######################### Server info preparation

mkdir -p $JENKINS_TA_TEMP_DIR
if [ "$HANA_SERVER_ADDRESS" == "master" ]; then
	HANA_SERVER_ADDRESS=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
fi
###################################################################################################################################################################
######################### Preparing the temp folder and installer packages
###################################################################################################################################################################
EXACT_PKG_PATH=$(echo $EXACT_PKG_PATH | sed -e 's/\\/\//g')
if [ -z "$EXACT_PKG_PATH" ]; then
        if [ ! -d "$MNT_PATH" ]; then
                echo "######################### mount folder does not exist, creating..."
                mkdir -p "$MNT_PATH"
        fi
        echo "Find the latest product package..."
        PKG_PATH=$(ls "$MNT_PATH"/*.HANA/Product_*.rar | sort -r | awk "NR==1" | awk '{ print $1 }')
        if [ ! -f "$PKG_PATH" ]; then
                echo "######################### Cannot find package, mounting..."
                mount.cifs -o username=$BUILDS_SHARE_FOLDER_USER,password=$BUILDS_SHARE_FOLDER_PWD,domain=$BUILDS_SHARE_FOLDER_DOMAIN "$BUILD_PATH" "$MNT_PATH"
        fi
        echo "######################### Find the latest product package..."
        PKG_PATH=$(ls "$MNT_PATH"/*.HANA/Product_*.rar | sort -r | awk "NR==1" | awk '{ print $1 }')
	CLIENT_PATH=$(ls "$MNT_PATH"/*.HANA/Client_*.zip | sort -r | awk "NR==1" | awk '{ print $1 }')
else
        echo "The build package path is: "$EXACT_PKG_PATH
	BUILD_PATH=$EXACT_PKG_PATH
        if [ ! -d "$MNT_PATH" ]; then
                echo "######################### Temp folder for build package does not exist, creating..."
                mkdir -p "$MNT_PATH"
        fi
        echo "mounting..."
        mount.cifs -o username=$BUILDS_SHARE_FOLDER_USER,password=$BUILDS_SHARE_FOLDER_PWD,domain=$BUILDS_SHARE_FOLDER_DOMAIN "$EXACT_PKG_PATH" "$MNT_PATH"
        echo "######################### Finding the product package..."
        PKG_PATH=$(ls "$MNT_PATH"/Product_*.rar | sort -r | awk "NR==1" | awk '{ print $1 }')
	CLIENT_PATH=$(ls "$MNT_PATH"/Client_*.zip | sort -r | awk "NR==1" | awk '{ print $1 }')
fi
if [ ! -f "$PKG_PATH" ]; then
        echo "######################### Cannot find the product pakcage..."
        exit 1
fi
echo "######################### Extracting..."
pushd "$JENKINS_TA_TEMP_DIR"
rar x "$PKG_PATH" "$INSTALLER_PKG_NAME"
popd
umount -l $MNT_PATH
###################################################################################################################################################################
######################### Installing 
###################################################################################################################################################################
rm -rf $INSTALL_PROP_PATH
cp "$WORKSPACE/jenkins/scripts/install.properties" "$INSTALL_PROP_PATH"
sed -i --expression="s/%ADDR%/$HANA_SERVER_ADDRESS/g" "$INSTALL_PROP_PATH"
sed -i --expression="s/%INSNUM%/$HANA_INSTANCE_NUM/g" "$INSTALL_PROP_PATH"
sed -i --expression="s/%USER%/$HANA_INSTANCE_USER/g" "$INSTALL_PROP_PATH"
sed -i --expression="s/%PWD%/$HANA_INSTANCE_PWD/g" "$INSTALL_PROP_PATH"
sed -i --expression="s/%FEATURES%/$ALL_FEATURES/g" "$INSTALL_PROP_PATH"
chmod -R +x "$INSTALL_BIN_PATH" 
pushd "$INSTALL_BIN_PATH"
./install.bin --debug -i silent -f install.properties
RESULT=$?
popd
rm -rf "$JENKINS_TA_TEMP_DIR"
if [ $RESULT -ne 0 ]; then
	echo "######################### Installation failed:"$RESULT
	exit $RESULT
fi
CLIENT_PATH=${CLIENT_PATH//$MNT_PATH/$BUILD_PATH}
CLIENT_PATH=$(echo $CLIENT_PATH | sed -e 's/\//\\/g')
rm -rf "$WORKSPACE/client"
rm -rf "$WORKSPACE/pkgdir"
touch "$WORKSPACE/client"
touch "$WORKSPACE/pkgdir"
echo "$CLIENT_PATH" > "$WORKSPACE/client"
echo ${CLIENT_PATH%\Client_*} > "$WORKSPACE/pkgdir"
echo "######################### Installation successful"
exit $RESULT
