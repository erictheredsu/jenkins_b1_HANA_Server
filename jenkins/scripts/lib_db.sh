#!/bin/bash
#
#	basic db operation
#
#

TMP_RST_FILE="${WORKSPACE}/result"
TMP_PKG_DIR="${WORKSPACE}/pkg"
HDB_INST_SRV=`ps aux | grep HDB${HDB_INST}/exe/sapstartsrv | grep -v grep | awk '{print $11}' | awk "NR==1"`
HDB_INST_OWNER=`ps aux | grep HDB${HDB_INST}/exe/sapstartsrv | grep -v grep | awk '{print $1}' | awk "NR==1"`
HDB_INST_SID=`ps aux | grep HDB${HDB_INST}/exe/sapstartsrv | grep -v grep | awk '{print $1}' | awk "NR==1" | tr 'a-z' 'A-Z' | cut -c 1-3`
HDB_INST_PATH=${HDB_INST_SRV%/exe*}
HDB_GROUP="sapsys"
HDB_BACKUP_DIR="${HDB_INST_PATH}/jenkins/${BACKUP_TYPE}"
HDB_BACKUP_BASE="${HDB_BACKUP_DIR}/${BACKUP_TYPE}"
COMPS=()
PKG_ARRAY=("sbo")

export PATH=$HDB_CLIENT:$PATH
export REGI_HOST=${HDB_HOST}:3${HDB_INST}15
export REGI_USER=${HDB_SYSTEM}
export REGI_PASSWD=${HDB_SYSTEM_PWD}

function precheck() {
	if [ ! -d "$HDB_CLIENT" ]; then
		echo "Cannot find the HANA client installed: $HDB_CLIENT"
	    return 1
	fi
	proc=`ps aux | grep HDB${HDB_INST} | grep -v grep | wc -l`
	if [ $proc -lt 4 ]; then
		echo "HANA instance is in anormal status, please check..."
	    return 1
	fi
}

function rmQuote() {
	echo $1 | tr -d '"'
}

function getResult() {
	if [ ! -f "$TMP_RST_FILE" ]; then
		return 1;
	fi
	for line0 in "$(cat "$TMP_RST_FILE")"
	do
       	start=$(echo "$line0" | awk '{print $1}')
		if [ "$start" == "*" ]; then
			return `echo "$line0" | awk '{print $2}' | tr -d ":"`;
		fi
	done
	return 0;
}

function checkErr() {
	getResult
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
    	exit $RESULT
    fi
}

function executeSQL() {
	pushd "$HDB_CLIENT"
		hdbsql -i "$HDB_INST" -u "$HDB_SYSTEM" -p "$HDB_SYSTEM_PWD" -o "$TMP_RST_FILE" $1
	popd
}

function backup() {
	echo "backup HDB instance ${HDB_HOST}:${HDB_INST} to ${HDB_BACKUP_BASE}..."

	rm -rf "${HDB_BACKUP_DIR}"
	mkdir -p "${HDB_BACKUP_DIR}"
	chown -R $HDB_INST_OWNER:$HDB_GROUP "${HDB_BACKUP_DIR}"
	executeSQL "backup data all using file ('${HDB_BACKUP_BASE}')"
	checkErr
}


function cleanupBackupLogs() {
	echo "remove logs for HDB instance ${HDB_HOST}:${HDB_INST}..."
	LOG_FOLDER="/hana/shared/${HDB_INST_SID}/HDB${HDB_INST}/backup/log"
	if [ -d ${LOG_FOLDER} ]; then
		rm -rf ${LOG_FOLDER}/*
	fi
}

function swipe_db() {
	# cleanup db brutally without backup/restore
	removeHDBUser
	getCompDBs
	removePKGs
	removeCommon
	removeSBOCommon
	removeSLDData
	# removeCompDBs
	removeTargetDBs
	cleanupBackupLogs
}

function cleanupdb() {
	if [ ! -d "${HDB_BACKUP_DIR}" ] || [ -z "$(ls -A ${HDB_BACKUP_DIR})" ]; then
		echo "No backup found, start to backup..."
		removeHDBUser
		getCompDBs
		removePKGs
		removeCommon
		removeSBOCommon
		removeSLDData
		removeCompDBs
		backup
	else
		echo "Start to recovery..."
		restore
	fi
	cleanupBackupLogs
}

function restore() {
	echo "recovery HDB instance ${HDB_HOST}:${HDB_INST} from ${HDB_BACKUP_BASE}..."

	su - $HDB_INST_OWNER <<EOF
	$HDB_INST_PATH/HDB stop
	pushd $HDB_INST_PATH/exe/python_support
	python recoverSys.py --masterOnly --command="recover data all using file ('${HDB_BACKUP_BASE}') clear log"
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		exit $RESULT
	fi 
EOF

	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		exit $RESULT
	fi
	timer=60
	count=0
	RST=`su - $HDB_INST_OWNER -c "sapcontrol -nr $HDB_INST -function GetProcessList | grep GREEN | wc -l"`
	until [ $RST -ge 7 ] || [ $count -gt $timer ]; do
	   	sleep 10
	   	RST=`su - $HDB_INST_OWNER -c "sapcontrol -nr $HDB_INST -function GetProcessList | grep GREEN | wc -l"`
	   	let count="${count}+1"
	done
	if [ $RST -lt 7 ]; then
	    	echo "recovery failed within 10 min..."
		exit 1
	fi
    cleanupBackupLogs
}


function removeCommon() {
	echo "remove COMMON schema on HDB instance ${HDB_HOST}:${HDB_INST}..."

	COLUMN_NAME="SCHEMA_OWNER"
	COMMON_USER=""
	executeSQL "select $COLUMN_NAME from SYS.SCHEMAS where SCHEMA_NAME='COMMON'"
	num=0
	checkErr
	for LINE in $(cat "$TMP_RST_FILE")
	do   
        	if [ $num -eq 0 ]; then
			if [ "$LINE" != "$COLUMN_NAME" ]; then
				echo "Failed to execute \"select $COLUMN_NAME from SYS.SCHEMAS where SCHEMA_NAME='COMMON'\", error:"
				echo "$(cat "$TMP_RST_FILE")"
				exit 1
			fi
		elif [ $num -eq 1 ]; then
			COMMON_USER=`rmQuote "$LINE"`
		fi
		let num="${num}+1"
	done
	if [ "$COMMON_USER" == "COMMON" ]; then
		echo "Drop user COMMON..."
		executeSQL "DROP USER COMMON CASCADE"
		checkErr
	elif [ ! -z "$COMMON_USER" ] && [ "$COMMON_USER" != "SYSTEM" ]; then
		echo "Drop schema COMMON..."
		executeSQL "DROP SCHEMA COMMON CASCADE"
		checkErr
	fi
}
function removeSBOCommon() {
	echo "remove SBOCOMMON schema on HDB instance ${HDB_HOST}:${HDB_INST}..."

	COLUMN_NAME="EXIST_SCHEMA"
	num=0
	EXIST_SCHEMA_SBOCOMMON=0
	executeSQL "select 1 as \"$COLUMN_NAME\" from SYS.SCHEMAS where SCHEMA_NAME='SBOCOMMON'"
	checkErr
	for LINE in $(cat "$TMP_RST_FILE")
        do
		if [ $num -eq 0 ]; then
                        if [ "$LINE" != "$COLUMN_NAME" ]; then
                                echo "Failed to execute \"select 1 as \"$COLUMN_NAME\" from SYS.SCHEMAS where SCHEMA_NAME='SBOCOMMON'\", error:"
                                echo "$(cat "$TMP_RST_FILE")"
                                exit 1
                        fi
        elif [ $num -eq 1 ]; then
                        EXIST_SCHEMA_SBOCOMMON=`rmQuote $LINE`
        fi
		let num="${num}+1"
	done
	if [ $EXIST_SCHEMA_SBOCOMMON -gt 0 ]; then
		echo "Drop schema SBOCOMMON..."
		executeSQL "DROP SCHEMA SBOCOMMON CASCADE"
		checkErr
	fi
}
function removeSLDData() {
	echo "remove SLDDATA schema on HDB instance ${HDB_HOST}:${HDB_INST}..."

	COLUMN_NAME="EXIST_SCHEMA"
    num=0
    EXIST_SCHEMA_SLDDATA=0
    executeSQL "select 1 as \"$COLUMN_NAME\" from SYS.SCHEMAS where SCHEMA_NAME='SLDDATA'"
	checkErr
    for LINE in $(cat "$TMP_RST_FILE")
    do
        if [ $num -eq 0 ]; then
                if [ "$LINE" != "$COLUMN_NAME" ]; then
						echo "Failed to execute \"select 1 as \"$COLUMN_NAME\" from SYS.SCHEMAS where SCHEMA_NAME='SLDDATA'\", error:"
                        echo "$(cat "$TMP_RST_FILE")"
                        exit 1
                fi
        elif [ $num -eq 1 ]; then
                EXIST_SCHEMA_SLDDATA=`rmQuote $LINE`
        fi
        let num="${num}+1"
    done
    if [ $EXIST_SCHEMA_SLDDATA -gt 0 ]; then
        echo "Drop schema SLDDATA..."
        executeSQL "DROP SCHEMA SLDDATA CASCADE"
	checkErr
    fi
}
function getCompDBs() {
    echo "fetch all b1 company schemas on HDB instance ${HDB_HOST}:${HDB_INST}..."

    num=0
    temp_num=0
    COLUMN_NAME="SCHEMA_NAME"
    executeSQL "select $COLUMN_NAME from SYS.TABLES where TABLE_NAME = 'CINF'"
    checkErr
    for LINE in $(cat "$TMP_RST_FILE")
    do
        if [ $num -eq 0 ]; then
            if [ "$LINE" != "$COLUMN_NAME" ]; then
                    echo "Failed to execute \"select $SCHEMA_NAME from SYS.TABLES where TABLE_NAME = 'CINF'\", error:"
                    echo "$(cat "$TMP_RST_FILE")"
                    exit 1
            fi
        else
            COMP_NAME=`rmQuote $LINE`
			COMPS[$temp_num]=$COMP_NAME
            PKG_ARRAY[$num]=`echo $COMP_NAME | tr 'A-Z' 'a-z'`
            let temp_num="${temp_num}+1"
        fi
        let num="${num}+1"
    done
}
function removeTargetDBs() {
	echo "remove target b1 company schemas on HDB instance ${HDB_HOST}:${HDB_INST}..."

	targetDBs=()
	temp_num=0

	if [ "${SBOTESTUS}" == "true" ]; then
		targetDBs[$temp_num]="SBOTESTUS"
		let temp_num="${temp_num}+1"
	fi
	if [ "${SBOTESTCN}" == "true" ]; then
		targetDBs[$temp_num]="SBOTESTCN"
		let temp_num="${temp_num}+1"
	fi	
	if [ "${SBOTESTDE}" == "true" ]; then
		targetDBs[$temp_num]="SBOTESTDE"
		let temp_num="${temp_num}+1"
	fi

    for comp in ${targetDBs[@]}
    do
		echo "Drop company $comp..."
		executeSQL "DROP SCHEMA \"$comp\" CASCADE"
		# checkErr
    done
}
function removeCompDBs() {
	echo "remove all b1 company schemas on HDB instance ${HDB_HOST}:${HDB_INST}..."

    for comp in ${COMPS[@]}
    do
		echo "Drop company $comp..."
		executeSQL "DROP SCHEMA \"$comp\" CASCADE"
		checkErr
    done
}
function removePKGs() {
	echo "remove content on HDB instance ${HDB_HOST}:${HDB_INST}..."

	rm -rf "$TMP_PKG_DIR"
	mkdir -p "$TMP_PKG_DIR"
	pushd "$TMP_PKG_DIR"
	regi create workspace ws --force
	popd
	pushd "$TMP_PKG_DIR/ws" 
	for pkg in ${PKG_ARRAY[@]}
	do
    	echo "Track the package: sap.$pkg"
		regi track package sap.$pkg
	done
	regi checkout --force
	rm -rf sap
	regi commit
	regi activate
	for pkg in $PKG_ARRAY
        do
		echo "Delete the package: sap.$pkg"
		regi delete packages sap.$pkg
	done
	popd
	rm -rf "$TMP_PKG_DIR"
}

function removeHDBUser() {
	if [ -z "${HDB_USR}" ] || [ "${HDB_USR}" == "${HDB_SYSTEM}" ]; then
		return 0
	fi
	hdbsql -i "$HDB_INST" -u "$HDB_SYSTEM" -p "$HDB_SYSTEM_PWD" -a -x -j "drop user ${HDB_USR} cascade" 
	RESULT=$?
	return $RESULT
}

function createHDBUser() {
	if [ -z "${HDB_USR}" ] || [ "${HDB_USR}" == "${HDB_SYSTEM}" ]; then
		return 0
	fi
	if [ -z "${HDB_PWD}" ]; then
		echo "!!HDB_PWD has no value"
		return 1;
	fi
	B1ADMIN_EXIST=$(hdbsql -i "$HDB_INST" -u "$HDB_SYSTEM" -p "$HDB_SYSTEM_PWD" -a -x -j "select 1 from USERS where \"USER_NAME\" = '${HDB_USR}'")
	if [ -n "${B1ADMIN_EXIST}" ]; then
		hdbsql -i "$HDB_INST" -u "$HDB_SYSTEM" -p "$HDB_SYSTEM_PWD" -a -x -j "drop user ${HDB_USR} cascade" 
	fi
	rm -f ${WORKSPACE}/test.sql
	cp -f /home/jenkins/tools/artifacts/scripts/${BRANCH}_user.sql ${WORKSPACE}/test.sql
	sed -i s/B1ADMIN/${HDB_USR}/g test.sql
	sed -i s/Manager1/${HDB_SYSTEM_PWD}/g test.sql
	sed -i s/Initial0/${HDB_PWD}/g test.sql
	hdbsql -i "$HDB_INST" -u "$HDB_SYSTEM" -p "$HDB_SYSTEM_PWD" -I ${WORKSPACE}/test.sql
	RESULT=$?
	return $RESULT
}

# mark
echo "lib_db.sh imported successfuly"

# precheck the HDB server and client
precheck
