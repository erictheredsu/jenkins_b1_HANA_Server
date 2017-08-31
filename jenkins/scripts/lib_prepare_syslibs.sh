#!/bin/bash

#environment variables
#TOOLS_HOME e.g.: /home/jenkins/tools

#local variables
FILE_SUSE_RELEASE="/etc/SuSE-release"
STR_SUSE="SUSE Linux Enterprise Server 11"
STR_SP2="PATCHLEVEL = 2"
STR_SP3="PATCHLEVEL = 3"
STR_SP4="PATCHLEVEL = 4"
SUSE_SP2_ISO_NAME=SUSE_SLES-11-SP2-DVD-x86_64-GM-DVD1.iso
SUSE_SP3_ISO_NAME=SLES-11-SP3-DVD-x86_64-GMC2-DVD1.iso
SUSE_SP4_ISO_NAME=SLES-11-SP4-DVD-x86_64-GM-DVD1.iso
repo_name=ci_repo_suse_iso
declare -a lib_list=(glibc libgcrypt11 libgpg-error0 glibc-i18ndata 
	libidn libgcc46 libldap-2_4-2 libstdc++46 libcurl4 
	krb5 libcom_err2 keyutils-libs zlib cyrus-sasl 
	libaio pam cron openssl)

SUSE_ISO_PATH=${TOOLS_HOME}

#function for preparation
function precheck() {
	# check SuSE version
	grep -q "$STR_SUSE" $FILE_SUSE_RELEASE
	if [ "$?" -ne "0" ]; then
		echo "Only support SUSE Linux Enterprise Server 11"
		exit 1
	fi

	local find=false
	grep -q "$STR_SP2" $FILE_SUSE_RELEASE
	if [ "$?" -eq "0" ]; then
		find=true
		iso=$SUSE_ISO_PATH/$SUSE_SP2_ISO_NAME
		echo "Your system is SUSE Linux Enterprise Server 11 SP2"
	fi

	if [ $find == "false" ]; then
		grep -q "$STR_SP3" $FILE_SUSE_RELEASE
		if [ "$?" -eq "0" ]; then
			find=true
			iso=$SUSE_ISO_PATH/$SUSE_SP3_ISO_NAME
			echo "Your system is SUSE Linux Enterprise Server 11 SP3"
		fi
	fi
        if [ $find == "false" ]; then
                grep -q "$STR_SP4" $FILE_SUSE_RELEASE
                if [ "$?" -eq "0" ]; then
                        find=true
                        iso=$SUSE_ISO_PATH/$SUSE_SP4_ISO_NAME
                        echo "Your system is SUSE Linux Enterprise Server 11 SP4"
                fi
        fi

	
	if [ $find == "false" ]; then
		echo "Only support SUSE Linux Enterprise Server 11 SP2, SP3 and SP4"
		exit 1
	fi

	if ! [ -e $iso ]; then
		echo "SUSE iso file doesn't exist; please check environment variable TOOLS_HOME and iso file in the path"
		exit 1
	fi
}

#function for installing lib
function installLibs() {
	#"zypper ar 'iso:///?iso="$SUSE_ISO_NAME"&nfs:///"$MASTER_SERVER_ADDRESS$SUSE_ISO_PATH"' "$repo_name

	echo "using iso:"$iso
	zypper ar -c -t yast2 'iso:/?iso='"$iso" $repo_name
	#zypper lr
	zypper refresh

	local strLibs=""
	for i in ${lib_list[@]}
	do
		strLibs+=" "$i
	done
	echo "installing... "$strLibs
	zypper --non-interactive in -r $repo_name$strLibs
	return $?
}

#function for clean
function clean() {
	zypper rr $repo_name
}

#main function
function prepareSysLibs() {
	#STEP 1: precheck
	precheck

	#STEP 2: install sys libs
	installLibs
	RESULT=$?
	#STEP 3: clean
	clean
	if [ "${RESULT}" != "0" ]; then
		echo "failed to install the sys lib..."
	fi
	exit ${RESULT}
}

echo "lib_prepare_syslibs.sh imported successfully"
