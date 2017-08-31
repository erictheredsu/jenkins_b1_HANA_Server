#!/bin/bash
#HDB_INST
#HDB_USR
#HDB_PWD
#NON_SYSTEM_USER
#NON_SYSTEM_PWD
#BRANCH
. ${0%/*}/lib_core.sh
. ${0%/*}/lib_db.sh

createHDBUser
RESULT=$?
if [ $RESULT -ne 0 ]; then
	qset "JOB_RESULT" "false"
else
	qset "JOB_RESULT" "true"
fi