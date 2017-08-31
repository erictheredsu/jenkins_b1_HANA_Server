#!/bin/bash

#required env variables
#HDB_HOST
#ROOT_PWD
#HDB_INST
#HDB_USR
#HDB_PWD
#HDB_CLIENT

HDBSQL="$HDB_CLIENT/hdbsql"

function precheck() {
    checkHDBHost
    if [ $? -ne 0 ]; then
        echo "Cannot connect to host -> "$HDB_HOST
        exit -1
    fi

    checkRootPwd
    if [ $? -ne 0 ]; then
        echo "root password is wrong -> "$ROOT_PWD
        exit -1
    fi

    checkHANA
    if [ $? -ne 0 ]; then
        echo "cannot connect to HANA server -> "$HDB_HOST:3${HDB_INST}15" with "$HDB_USR"/"$HDB_PWD
        exit -1
    fi

    return 0
}

function checkHDBHost() {
    echo "checking HDB_HOST..."
    # HDB_HOST must be IP address
    ip=$HDB_HOST

    # ping the host
    echo "ping HDB host... "$ip
    ping -c 1 $ip

    if [ $? -eq 0 ]; then
        echo "ping $ip success"
    else
        echo "ping $ip fail"
        return -1
    fi
}

#remote call function
function RemoteCall() {
    local host=$1
    local uid=$2
    local pwd=$3
    local cmd=$4
    if [ "$host" != "" ] && [ "$uid" != "" ]; then
        local cmd="ssh -l $uid $host $cmd"
    fi
    echo "run cmd: "$cmd
    expect -c "
            set timeout 5
            spawn $cmd
            while (1) {
            expect {
                  \"Password:\"         {send \"$pwd\r\"}
                  \"RSA key\"           {send \"yes\r\"}
                  \"Continue*\"         {send \"\r\"}
                  \"Permission denied\" {exit 1}
                  eof                   {exit 0}
                }
            }
        "
}

function checkRootPwd() {
    # try login server with root
    echo "checking root password..."
    echo "run ls command for test connection"
    RemoteCall $HDB_HOST root $ROOT_PWD "ls | wc -l"
}
    

function checkHANA() {
    # connect to HANA server and exec simple sql
    # HDB_INST, HDB_USR and HDB_PWD 
    
    echo "checking HANA server..."
    sql="SELECT 123 FROM DUMMY"
    tmp_sql_result_file=./CI_TMP_SQL_RESULT

    "$HDBSQL" -n ${HDB_HOST}:3${HDB_INST}15 -o $tmp_sql_result_file -u ${HDB_USR} -p ${HDB_PWD} $sql
    if [ "$?" -ne "0" ]; then
        echo "Run simple query failed"
        rm $tmp_sql_result_file
        return -1
    fi

    rm $tmp_sql_result_file
}

echo "precheck.sh successfully imported."
precheck