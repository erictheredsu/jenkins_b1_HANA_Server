#!/bin/bash
##	HANA_INSTANCE_NUM
##	HANA_INSTANCE_USER
##	HANA_INSTANCE_PWD
##  HANA_CLIENT_PATH
FORCE_BK=false
REMOTE_HANA_CLIENT=false
export PATH=$HANA_CLIENT_PATH:$PATH
TMP_RST_FILE="$WORKSPACE/result"
TMP_PKG_DIR="$WORKSPACE/pkg"
HANA_INSTANCE_ADDRESS=`hostname -f`
HANA_INSTANCE_SRV=`ps aux | grep HDB${HANA_INSTANCE_NUM}/exe/sapstartsrv | grep -v grep | awk '{print $11}' | awk "NR==1"`
HANA_INSTANCE_PATH=${HANA_INSTANCE_SRV%/exe*}
HANA_INSTANCE_OWNER=`ps aux | grep HDB${HANA_INSTANCE_NUM}/exe/sapstartsrv | grep -v grep | awk '{print $1}' | awk "NR==1"`
HANA_INSTANCE_OWNER_GROUP="sapsys"
HANA_INSTANCE_SYSID=`echo ${HANA_INSTANCE_ADMIN%adm} | tr 'a-z' 'A-Z'`
HANA_INSTANCE_BK_DIR="$HANA_INSTANCE_PATH/JENKINS_BK"
CURRENT_TIMESTAMP=$(date +"%Y%m%d%H%M")
if [ $REMOTE_HANA_CLIENT == "false" ]; then
	HANA_INSTANCE_ADDRESS="127.0.0.1"
fi
export REGI_HOST=${HANA_INSTANCE_ADDRESS}:3${HANA_INSTANCE_NUM}15
export REGI_USER=$HANA_INSTANCE_USER
export REGI_PASSWD=$HANA_INSTANCE_PWD
COMPS=()
PKG_ARRAY=("sbo")
echo "HANA instance: "
echo "	Instance Address: $HANA_INSTANCE_ADDRESS"
echo "	Instance Number: $HANA_INSTANCE_NUM"
echo "	Instance System ID: $HANA_INSTANCE_SYSID"
echo "	Instance Directory: $HANA_INSTANCE_PATH"
## Precheck
if [ ! -d "$HANA_CLIENT_PATH" ]; then
	echo "Cannot find the HANA client installed: $HANA_CLIENT_PATH"
    exit 1
fi
HANA_PROCESS_NUM=`ps aux | grep HDB${HANA_INSTANCE_NUM} | grep -v grep | wc -l`
if [ $HANA_PROCESS_NUM -lt 4 ]; then
	echo "HANA instance is in anormal status, please check..."
    exit 1
fi
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
function ifError() {
	getResult
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
    	exit $RESULT
    fi
}
function executeSQL() {
	pushd "$HANA_CLIENT_PATH"
		hdbsql -i "$HANA_INSTANCE_NUM" -u "$HANA_INSTANCE_USER" -p "$HANA_INSTANCE_PWD" -o "$TMP_RST_FILE" $1
	popd
}
function removeCommon() {
	echo "############################## Remove COMMON"
	COLUMN_NAME="SCHEMA_OWNER"
	COMMON_USER=""
	executeSQL "select $COLUMN_NAME from SYS.SCHEMAS where SCHEMA_NAME='COMMON'"
	num=0
	ifError
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
		ifError
	elif [ ! -z "$COMMON_USER" ] && [ "$COMMON_USER" != "SYSTEM" ]; then
		echo "Drop schema COMMON..."
		executeSQL "DROP SCHEMA COMMON CASCADE"
		ifError
	fi
}
function removeSBOCommon() {
	echo "############################## Remove SBOCOMMON"
	COLUMN_NAME="EXIST_SCHEMA"
	num=0
	EXIST_SCHEMA_SBOCOMMON=0
	executeSQL "select 1 as \"$COLUMN_NAME\" from SYS.SCHEMAS where SCHEMA_NAME='SBOCOMMON'"
	ifError
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
		ifError
	fi
}
function removeSLDData() {
	echo "############################## Remove SLDDATA"
	COLUMN_NAME="EXIST_SCHEMA"
        num=0
        EXIST_SCHEMA_SLDDATA=0
        executeSQL "select 1 as \"$COLUMN_NAME\" from SYS.SCHEMAS where SCHEMA_NAME='SLDDATA'"
		ifError
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
		ifError
        fi
}
function getCompDBs() {
        echo "############################## Get company DBs"
        num=0
        temp_num=0
        COLUMN_NAME="SCHEMA_NAME"
        executeSQL "select $COLUMN_NAME from SYS.TABLES where TABLE_NAME = 'CINF'"
        ifError
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
function removeCompDBs() {
	echo "############################## Remove company DBs"
        for comp in ${COMPS[@]}
        do
			echo "Drop company $comp..."
			executeSQL "DROP SCHEMA \"$comp\" CASCADE"
			ifError
        done
}
function removePKGs() {
	echo "############################## Remove content package"
	rm -rf "$TMP_PKG_DIR"
	mkdir -p "$TMP_PKG_DIR"
	pushd "$TMP_PKG_DIR"
	regi create workspace ws
	popd
	pushd "$TMP_PKG_DIR/ws" 
	for pkg in ${PKG_ARRAY[@]}
	do
    		echo "Track the package: sap.$pkg"
		regi track package sap.$pkg
	done
	regi checkout
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
function backup() {
	echo "############################## Backup all data"
	rm -rf "$HANA_INSTANCE_BK_DIR"
	mkdir -p "$HANA_INSTANCE_BK_DIR"
	chown -R $HANA_INSTANCE_OWNER:$HANA_INSTANCE_OWNER_GROUP "$HANA_INSTANCE_BK_DIR"
	executeSQL "backup data all using file ('$HANA_INSTANCE_BK_DIR/$CURRENT_TIMESTAMP')"
	ifError
}
function recovery() {
	echo "############################## Recovery all data"
    	TIMESTAMP=`ls -t $HANA_INSTANCE_BK_DIR | awk '{print $1}' | awk "NR==1"`
    	TIMESTAMP=${TIMESTAMP%_databackup*}
su - $HANA_INSTANCE_OWNER <<EOF
$HANA_INSTANCE_PATH/HDB stop
pushd $HANA_INSTANCE_PATH/exe/python_support
python recoverSys.py --masterOnly --command="recover data all using file ('$HANA_INSTANCE_BK_DIR/$TIMESTAMP') clear log"
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
RST=`su - $HANA_INSTANCE_OWNER -c "sapcontrol -nr $HANA_INSTANCE_NUM -function GetProcessList | grep GREEN | wc -l"`
until [ $RST -eq 8 ] || [ $count -gt $timer ]; do
   	sleep 10
   	RST=`su - $HANA_INSTANCE_OWNER -c "sapcontrol -nr $HANA_INSTANCE_NUM -function GetProcessList | grep GREEN | wc -l"`
   	let count="${count}+1"
done
if [ $RST -ne 8 ]; then
    	echo "Recovery failed within 10 min..."
	exit 1
fi
    #$HANA_INSTANCE_PATH/HDB start   
}
if [ ! -d "$HANA_INSTANCE_BK_DIR" ] || [ -z "$(ls -A "$HANA_INSTANCE_BK_DIR")" ]; then
	echo "No backup found, start to backup..."
	getCompDBs
	removePKGs
	removeCommon
	removeSBOCommon
	removeSLDData
	removeCompDBs
	backup
else
	echo "Start to recovery..."
	recovery
fi
exit 0
