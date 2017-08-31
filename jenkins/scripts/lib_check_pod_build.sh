#!/bin/bash
#
#	check a new pod build
#
#	output
# 	 HAS_NEW_POD_BUILD -> true/false
# 	 PREV_POD_BUILD_PATH -> \\10.58.5.101\builds_cn\SBO\dev\910.105.00_CNPVG50839504AV_SBO_EMEA_dev_030614_203930_1334938.HANA

# import the libs
. ${0%/*}/lib_core.sh

#POD_BUILDS_POOL=/home/jenkins/buildspace/builds49/
#POD_BUILDS_SHARE_FOLDER=//10.58.6.49/builds_cn/SBO/
#POD_BUILDS_SHARE_FOLDER_DOMAIN=SAP_ALL
#POD_BUILDS_SHARE_FOLDER_USER=****
#POD_BUILDS_SHARE_FOLDER_PWD=XXXX
#INSTALLER_PKG_NAME=Packages.Linux
#POD_MNT_PATH=/home/jenkins/buildspace/mnt49
#RAR_HOME=/home/jenkins/tools/rar
#BUILD_PKG
#BRANCH=dev

BRANCH_FOLDER="${BRANCH}_Linux"
BRANCH_POOL=${POD_BUILDS_POOL%/}/${BRANCH}
latest=""
tested_cl=""
extract_pkg_name=""
HAS_NEW_POD_BUILD=false

function checkPool() {
	if [[ ! -d ${BRANCH_POOL} ]]; then
		mkdir -p ${BRANCH_POOL}
	fi
	pushd ${BRANCH_POOL}
	tested_cl=$(ls |  grep -v prev | sort -r | awk "NR==1")
	popd
}
function mountBuildSrv() {
	if [ ! -d "${POD_MNT_PATH}" ]; then
	    echo "######################### mount folder does not exist, creating..."
        mkdir -p "${POD_MNT_PATH}"
    fi
	BRANCH_PATH=$(ls -d "${POD_MNT_PATH%/}"/${BRANCH_FOLDER} | awk "NR==1" | awk '{ print $1 }')
	if [ ! -d "${BRANCH_PATH}" ]; then
        echo "######################### Cannot find package, mounting..."
        mount.cifs -o username=${POD_BUILDS_SHARE_FOLDER_USER},password=${POD_BUILDS_SHARE_FOLDER_PWD} "${POD_BUILDS_SHARE_FOLDER}" "${POD_MNT_PATH}"
		BRANCH_PATH=$(ls -d "${POD_MNT_PATH%/}"/${BRANCH_FOLDER} | awk "NR==1" | awk '{ print $1 }')
    fi
	if [ ! -d "${BRANCH_PATH}" ]; then
		echo "######################### Cannot find the $BRANCH_FOLDER directory"
		exit 1
	fi
}
function findLatest() {
    echo "######################### Find the latest product package..."
	LATEST_CL=$(ls -d "${BRANCH_PATH%/}"/Packages_*.zip | sed "s:${BRANCH_PATH}::g" | sed "s:.zip::g" | awk -F "_" '{print $NF}' | sort -r | awk "NR==1")
	PKG_PATH=$(ls -t "${BRANCH_PATH%/}"/Packages_*_${LATEST_CL}.zip | awk "NR==1" | awk '{ print $1 }')
	temp=`echo ${PKG_PATH} | awk -F '/' '{print $NF}'`
	PREV_POD_BUILD_PATH=$(echo ${POD_BUILDS_SHARE_FOLDER}/${BRANCH_FOLDER}/${temp} | sed -e 's/\//\\/g')
	if [ ! -z ${tested_cl} ] && [ ${LATEST_CL} -le ${tested_cl} ]; then
		qset "HAS_NEW_POD_BUILD" "false"
		qset "PREV_POD_BUILD_PATH" "${PREV_POD_BUILD_PATH}"
		exit 0
	fi
	extract_pkg_name=${LATEST_CL}
	if [ -z ${extract_pkg_name} ]; then
		echo "######################### Cannot find the latest changelist"
		exit 1
	fi
	if [ ! -f $PKG_PATH ]; then
		echo "######################### Cannot find the Packages package"
		exit 1
	fi
}

function extractProduct() {
	echo "######################### Extracting..."
	rm -rf "${BRANCH_POOL%/}"
	mkdir -p "${BRANCH_POOL%/}/${extract_pkg_name}"
	pushd "${BRANCH_POOL%/}/${extract_pkg_name}"
	unzip ${PKG_PATH}
	if [ $? -ne 0 ]; then
		echo "failed to extract b1 product rar package; error code=$?"
		return 1
	fi
	POD_PKG="packages/ServerTools"
	FORMAT_PKG="${INSTALLER_PKG_NAME}/ServerComponents"
	mkdir -p "${FORMAT_PKG}"
	mv -f "${BRANCH_POOL%/}/${extract_pkg_name}/${POD_PKG}/"* "${FORMAT_PKG}"
	ln -s "${BRANCH_POOL%/}/${extract_pkg_name}" "${BRANCH_POOL%/}/prev"
	rm -rf "packages"
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
	fi
	qset "HAS_NEW_POD_BUILD" "true"
	qset "PREV_POD_BUILD_PATH" "${PREV_POD_BUILD_PATH}"
	# check result
	if [ $? -ne 0 ]; then
		exit $?
	fi
}

main

