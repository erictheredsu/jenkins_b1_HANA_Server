#!/bin/bash
#
#	check a new build
#
#	output
# 	 HAS_NEW_BUILD -> true/false
# 	 NEW_BUILD_PATH -> \\10.58.6.49\builds_cn\SBO\dev\910.105.00_CNPVG50839504AV_SBO_EMEA_dev_030614_203930_1334938.HANA
# 	 PREV_BUILD_PATH -> \\10.58.6.49\builds_cn\SBO\dev\910.105.00_CNPVG50839504AV_SBO_EMEA_dev_030614_203930_1334938.HANA

# import the libs
. ${0%/*}/lib_core.sh

#BUILDS_POOL=/home/jenkins/buildspace/builds49/
#BUILDS_SHARE_FOLDER=//10.58.6.49/builds_cn/SBO/
#BUILDS_SHARE_FOLDER_DOMAIN=SAP_ALL
#BUILDS_SHARE_FOLDER_USER=TA_admin
#BUILDS_SHARE_FOLDER_PWD=B1tA@VM2010
#INSTALLER_PKG_NAME=Packages.Linux
#MNT_PATH=/home/jenkins/buildspace/mnt49
#RAR_HOME=/home/jenkins/tools/rar
#BUILD_PKG
#BRANCH=dev


if [ ! -d $RAR_HOME ]; then
	echo "Cannot find rar tool for extracting package..."
	exit 1
fi
export PATH=$RAR_HOME:$PATH
BRANCH_POOL=${BUILDS_POOL%/}/$BRANCH
latest=""
tested_cl=""
extract_pkg_name=""
NEW_BUILD_PATH=""
PREV_BUILD_PATH=""
HAS_NEW_BUILD=false

function checkPool() {
	echo "######################### check the latest tested builds in builds pool..."
	if [ ! -d "$BRANCH_POOL" ]; then
		mkdir -p "$BRANCH_POOL"
	fi
	pushd "$BRANCH_POOL"
	prev=`ls -l prev | awk '{print $11}' | sed "s:$BRANCH_POOL::g"`
	prev=`echo $prev | tr -d "//"`
	new=`ls -l new | awk '{print $11}' | sed "s:$BRANCH_POOL::g" `
	new=`echo $new | tr -d "//"`
	if [ -z $new ]; then
		new=`ls | grep -v prev | grep -v new`
	fi
	if [ -z $new ] && [ ! -z $prev ] ; then
		new=$prev
	fi
	tested_cl=$(ls -d *.HANA | sed "s:.HANA::g" | awk -F "_" '{print $NF}' | sort -r | awk "NR==1")
	PREV_BUILD_PATH=$(echo ${BUILDS_SHARE_FOLDER%/}/$BRANCH/$prev | sed -e 's/\//\\/g')
	NEW_BUILD_PATH=$(echo ${BUILDS_SHARE_FOLDER%/}/$BRANCH/$prev | sed -e 's/\//\\/g')
	popd
}
function mountBuildSrv() {
	BRANCH_PATH="${MNT_PATH}${BRANCH}"
	if [ ! -d "${BRANCH_PATH}" ]; then
	    echo "######################### mount folder does not exist, creating..."
        mkdir -p "${BRANCH_PATH}"
    fi
	
    echo "######################### umounting the old shared folder..."
	umount -d "${BRANCH_PATH}"

	if [ -z ${MOUNT_SCRIPT} ]; then
		mount.cifs -o username=$BUILDS_SHARE_FOLDER_USER,password=$BUILDS_SHARE_FOLDER_PWD,domain=$BUILDS_SHARE_FOLDER_DOMAIN "$BUILDS_SHARE_FOLDER" "$MNT_PATH"
	else
			${MOUNT_SCRIPT}
	fi
	

	if [ ! -d $BRANCH_PATH ]; then
		echo "######################### Cannot find the $BRANCH directory"
		exit 1
	fi
}
function findLatest() {
    echo "######################### Find the latest product package..."
	LATEST_CL=$(ls -d "${BRANCH_PATH%/}"/*.HANA | sed "s:$BRANCH_PATH::g" | sed "s:.HANA::g" | awk -F "_" '{print $NF}' | sort -r | awk "NR==1")
	if [ ! -z $tested_cl ] && [ $LATEST_CL -le $tested_cl ]; then
		qset "HAS_NEW_BUILD" "false"
		qset "NEW_BUILD_PATH" "$NEW_BUILD_PATH"
	    qset "PREV_BUILD_PATH" "$PREV_BUILD_PATH"
		exit 0
	fi
	HAS_NEW_BUILD=true
    PKG_PATH=$(ls -t "${BRANCH_PATH%/}"/*$LATEST_CL.HANA/Product_*.rar | awk "NR==1" | awk '{ print $1 }')
	CLIENT_PATH=$(ls -t "${PKG_PATH%Product_*}"Client_*.zip | awk "NR==1" | awk '{ print $1 }')
	extract_pkg_name=`echo ${PKG_PATH%/Product_*} | sed s:$BRANCH_PATH::g`
	extract_pkg_name=`echo $extract_pkg_name | tr -d "//"`
	if [ -z $extract_pkg_name ]; then
		echo "######################### Cannot find the latest changelist"
		exit 1
	fi
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
	if [ -z "$BUILD_PKG" ]; then
		echo "######################### Please input the exact directory of product package"
		qset "HAS_NEW_BUILD" "false"
		qset "NEW_BUILD_PATH" "$NEW_BUILD_PATH"
		qset "PREV_BUILD_PATH" "$PREV_BUILD_PATH"
		exit 1
	fi
    echo "######################### Exact directory is: "$BUILD_PKG
    PKG_PATH=$(ls "${BRANCH_PATH%/}"/$BUILD_PKG/Product_*.rar | awk "NR==1" | awk '{ print $1 }')
	CLIENT_PATH=$(ls "${BRANCH_PATH%/}"/$BUILD_PKG/Client_*.zip | awk "NR==1" | awk '{ print $1 }')
	if [ ! -f $PKG_PATH ]; then
		echo "######################### Cannot find the Product package"
		qset "HAS_NEW_BUILD" "false"
		qset "NEW_BUILD_PATH" "$NEW_BUILD_PATH"
		qset "PREV_BUILD_PATH" "$PREV_BUILD_PATH"
		exit 1
	fi
	if [ ! -f $CLIENT_PATH ]; then
		echo "######################### Cannot find the Client package"
		qset "HAS_NEW_BUILD" "false"
		qset "NEW_BUILD_PATH" "$NEW_BUILD_PATH"
		qset "PREV_BUILD_PATH" "$PREV_BUILD_PATH"
		exit 1
	fi
	LATEST_CL=$(echo ${BUILD_PKG} | sed "s:.HANA::g" | awk -F "_" '{print $NF}' | sort -r | awk "NR==1")
	if [ -z ${tested_cl} ] || [ ${LATEST_CL} -ne ${tested_cl} ]; then
		HAS_NEW_BUILD=true
	else
		HAS_NEW_BUILD=false
	fi
	extract_pkg_name=$BUILD_PKG
}
function extractProduct() {
	echo "######################### Extracting..."

	EP_LIST_CMD=""
	EP_LIST=( "Demo.zip" "Integration.zip" "Sbo-AddOns.zip" "Sbo-Help.zip" )
    for comp in ${EP_LIST[@]}
    do
		EP_LIST_CMD="${EP_LIST_CMD} -x${INSTALLER_PKG_NAME}/ServerComponents/ZIP/${comp}"
    done

	rm -rf "${BRANCH_POOL%/}/$extract_pkg_name"
	rm -rf "${BRANCH_POOL%/}/new"
	mkdir -p "${BRANCH_POOL%/}/$extract_pkg_name"
	ln -s "${BRANCH_POOL%/}/$extract_pkg_name" "${BRANCH_POOL%/}/new"
	pushd "${BRANCH_POOL%/}/$extract_pkg_name"
	if [ $BRANCH == "9.1_REL" ] || [ $BRANCH == "9.1_DEV" ] || [ $BRANCH == "9.1_COR" ]; then
	#rar x ${EP_LIST_CMD} ${PKG_PATH} ${INSTALLER_PKG_NAME}
	#	rar x ${PKG_PATH}
		rar x ${EP_LIST_CMD} ${PKG_PATH} ${INSTALLER_PKG_NAME}
	else
	#	rar x ${EP_LIST_CMD} ${PKG_PATH} ${INSTALLER_PKG_NAME}
		rar x ${PKG_PATH} \
			"info.txt" \
        		"Packages.Linux" \
		        "Packages/Server/Upgrader Common" \
		        "Packages/Client" \
		        "Packages.x64/Client" \
		        "Packages/DI API" \
		        "Packages.x64/DI API" \
       			"Packages/SAP CRAddin Installation" \
		        "Packages/Server/ExclDocs" \
		        "Prerequisites" \
			${INSTALLER_PKG_NAME}
	fi 

	RESULT=$?
	if [ ${RESULT} -ne 0 ]; then
		echo "failed to extract b1 product rar package; error code=${RESULT}"
		return ${RESULT}
	fi

	cp -rf $CLIENT_PATH ./
	NEW_BUILD_PATH=$(echo "${BUILDS_SHARE_FOLDER%/}/$BRANCH/$extract_pkg_name" | sed -e 's/\//\\/g')
	popd
}


#
# entry point
#
function main() {
	mountBuildSrv
	checkPool
	if [ -z "$BUILD_PKG" ]; then
		findLatest
		extractProduct
	else
		findExact
		extractProduct
	fi
	
	# check result
	RESULT=$?
	if [ ${RESULT} -ne 0 ]; then
		exit ${RESULT}
	fi

	qset "HAS_NEW_BUILD" "$HAS_NEW_BUILD"
	qset "NEW_BUILD_PATH" "$NEW_BUILD_PATH"
	qset "PREV_BUILD_PATH" "$PREV_BUILD_PATH"
}

main
