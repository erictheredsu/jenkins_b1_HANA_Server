#!/bin/bash
# latest
# exact
# replace
###################################################################################################################################################################
######################### Preparing the environment variables
###################################################################################################################################################################
######################### Tools preparation
if [ ! -d $RAR_HOME ]; then
	echo "Cannot find rar tool for extracting package..."
	exit 1
fi
export PATH=$RAR_HOME:$PATH
######################### Package
BRANCH_PATH=
PKG_PATH=
CLIENT_PATH=
function mountBuildSrv() {
	if [ ! -d "$MNT_PATH" ]; then
	    echo "######################### mount folder does not exist, creating..."
        mkdir -p "$MNT_PATH"
    fi
	BRANCH_PATH=$(ls -d "$MNT_PATH"/$BRANCH | awk "NR==1" | awk '{ print $1 }')
	if [ ! -d "$BRANCH_PATH" ]; then
        echo "######################### Cannot find package, mounting..."
        mount.cifs -o username=$BUILDS_SHARE_FOLDER_USER,password=$BUILDS_SHARE_FOLDER_PWD,domain=$BUILDS_SHARE_FOLDER_DOMAIN "$BUILDS_SHARE_FOLDER" "$MNT_PATH"
		BRANCH_PATH=$(ls -d "$MNT_PATH"/$BRANCH | awk "NR==1" | awk '{ print $1 }')
        fi
	if [ ! -d $BRANCH_PATH ]; then
		echo "######################### Cannot find the $BRANCH directory"
		exit 1
	fi
}
function findLatest() {
    echo "######################### Find the latest product package..."
	LATEST_CL=$(ls -d "$BRANCH_PATH"/*.HANA | sed "s:$BRANCH_PATH::g" | sed "s:.HANA::g" | awk -F "_" '{print $8}' | sort -r | awk "NR==1")
    PKG_PATH=$(ls -t "$BRANCH_PATH"/*$LATEST_CL.HANA/Product_*.rar | awk "NR==1" | awk '{ print $1 }')
	CLIENT_PATH=$(ls -t "${PKG_PATH%Product_*}"Client_*.zip | awk "NR==1" | awk '{ print $1 }')
	if [ ! -f $PKG_PATH ]; then
		echo "######################### Cannot find the Product package"
		exit 1
	fi
	if [ ! -f $CLIENT_PATH ]; then
		echo "######################### Cannot find the Client package"
		exit 1
	fi
}
function findExact() {
	if [ -z "$EXACT_PKG_PATH" ]; then
		echo "######################### Please input the exact directory of product package"
		exit 1
	fi
    echo "######################### Exact directory is: "$EXACT_PKG_PATH
    PKG_PATH=$(ls "$BRANCH_PATH"/$EXACT_PKG_PATH/Product_*.rar | awk "NR==1" | awk '{ print $1 }')
	CLIENT_PATH=$(ls "$BRANCH_PATH"/$EXACT_PKG_PATH/Client_*.zip | awk "NR==1" | awk '{ print $1 }')
	if [ ! -f $PKG_PATH ]; then
		echo "######################### Cannot find the Product package"
		exit 1
	fi
	if [ ! -f $CLIENT_PATH ]; then
		echo "######################### Cannot find the Client package"
		exit 1
	fi
}
function extractProduct() {
	echo "######################### Extracting..."
	rm -rf "$BUILDS_POOL/$BRANCH/temp"
	mkdir -p "$BUILDS_POOL/$BRANCH/temp"
	pushd "$BUILDS_POOL/$BRANCH/temp"
	rar x "$PKG_PATH" "$INSTALLER_PKG_NAME"
	cp -rf $CLIENT_PATH ./
	CLIENT_PATH=`echo $CLIENT_PATH | sed "s:$MNT_PATH:$BUILDS_SHARE_FOLDER:g"`
	CLIENT_PATH=$(echo $CLIENT_PATH | sed -e 's/\//\\/g')
	echo "$CLIENT_PATH" > "client"
	echo ${CLIENT_PATH%\Client_*} > "pkgdir"
	popd
	export INSTALLER_DIR="$BUILDS_POOL/$BRANCH/temp"
}
function replaceRPM() {
	echo "######################### Replace rpm..."
	if [ $NEW_VALID == "true" ] || [ ! -d "$BUILDS_POOL/$BRANCH/temp_rpm" ]; then
		rm -rf "$BUILDS_POOL/$BRANCH/temp_rpm"
		mkdir -p "$BUILDS_POOL/$BRANCH/temp_rpm"
		if [ $(ls "$BUILDS_POOL/$BRANCH/rpm/*.rpm" | wc -l) -lt 2 ]; then
			echo "######################### Rpm files are not created or missing..."
			exit 1
		fi
		if [ $(ls -d "$BUILDS_POOL/$BRANCH/valid/$INSTALLER_PKG_NAME" | wc -l) ]; then
			echo "######################### Cannot find valid build..."
			exit 1
		fi
		cp -rf "$BUILDS_POOL/$BRANCH/valid/*" "$BUILDS_POOL/$BRANCH/temp_rpm/"
	fi
	rm -f $BUILDS_POOL/$BRANCH/temp_rpm/$INSTALLER_PKG_NAME/ServerComponents/RPM/B1AnalyticsPlatformCommon-*.rpm
	rm -f $BUILDS_POOL/$BRANCH/temp_rpm/$INSTALLER_PKG_NAME/ServerComponents/RPM/B1ServerToolsXApp-*.rpm
	cp -f "$BUILDS_POOL/$BRANCH/rpm/*.rpm" "$BUILDS_POOL/$BRANCH/temp_rpm/$INSTALLER_PKG_NAME/ServerComponents/RPM/"
}
