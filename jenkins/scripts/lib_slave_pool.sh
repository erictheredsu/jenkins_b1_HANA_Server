#!/bin/bash
#
#	find avaliable slave
#
# import the libs
. ${0%/*}/lib_core.sh

function findExactSlave() {
	echo "############################## Whether ${AVALIABLE_SLAVE} exists..."
    pushd ${SLAVE_POOL_LINUX}
    ls -d ${AVALIABLE_SLAVE}
    result=$?
    popd
    if [ -z ${AVALIABLE_SLAVE} ]; then
    	echo "############################## No available slave ${AVALIABLE_SLAVE}..."
    fi
    return ${result}
}

function findAvailableSlave() {
	echo "############################## Look for available slave..."
    pushd ${SLAVE_POOL_LINUX}
    AVALIABLE_SLAVE=`ls -d *_a | awk "NR==1"`
    popd
    if [ -z ${AVALIABLE_SLAVE} ]; then
    	echo "############################## No available slave..."
        return 1
    fi
    return 0
}

function occupySlave() {
	echo "############################## Try to occupy the slave"
    pushd ${SLAVE_POOL_LINUX}
    mv ${AVALIABLE_SLAVE} ${AVALIABLE_SLAVE%_a}
    result=$?
    popd
    if [ "${result}" == "0" ]; then
    	echo "############################## Update the job info"
    	pushd ${SLAVE_POOL_LINUX}/${AVALIABLE_SLAVE%_a}
    	if [ ! -f "BRANCH" ]; then
    		SAME_LAST_BRANCH=true
    	else
    		LAST_BRANCH=`cat BRANCH | tr -d "\n\r\t"`
    		if [ "${LAST_BRANCH}" == "${BRANCH}" ]; then
    			SAME_LAST_BRANCH=true
    		else
    			SAME_LAST_BRANCH=false
    		fi
    	fi
    	if [ ! -f "PROC" ]; then
    		SAME_LAST_PROC=true
    	else
    		LAST_PROC=`cat PROC | tr -d "\n\r\t"`
    		if [ "${LAST_PROC}" == "${PROC_NAME}" ]; then
    			SAME_LAST_PROC=true
    		else
    			SAME_LAST_PROC=false
    		fi
    	fi
    	echo "${BRANCH}" > BRANCH
    	echo "${PROC_NAME}" > PROC
    	popd
    fi
    return ${result}
}

function releaseSlave() {
	pushd ${SLAVE_POOL_LINUX}
	ls -d ${HDB_HOST}
	result=$?
	if [ "${result}" == "0" ]; then
		mv "${HDB_HOST}" "${HDB_HOST}_a"
    	result=$?
    	if [ "${result}" != "0" ]; then
    		echo "############################## Failed to release the slave..."
    	fi
	fi
}

#
# entry point
#
function main() {
	JOB_RESULT=true
	SAME_LAST_PROC=false
	SAME_LAST_BRANCH=false
	echo "SLAVE_ACTION=${SLAVE_ACTION}"
	if [ "${SLAVE_ACTION}" == "O" ]; then
    	if [ -z ${HDB_HOST} ]; then
        	hasAvaliable=0
        	occupied=1
        	until [ ${hasAvaliable} -eq 1 ] || [ ${occupied} -eq 0 ]; do
        		findAvailableSlave
        		hasAvaliable=$?
        		if [ ${hasAvaliable} -eq 0 ]; then
            		occupySlave
            		occupied=$?
            	fi
        	done
        	if [ -z ${AVALIABLE_SLAVE} ]; then
            	JOB_RESULT=false
        	else
        		HDB_HOST=${AVALIABLE_SLAVE}
        	fi
    	else
    		AVALIABLE_SLAVE="${HDB_HOST}_a"
    		result=$?
    		if [ ${result} != "0" ]; then
    			JOB_RESULT=false
    		fi
    		occupySlave
    		result=$?
    		if [ ${result} != "0" ]; then
    			JOB_RESULT=false
    		fi
    	fi
    else
    	releaseSlave
	fi
	qset "JOB_RESULT" "${JOB_RESULT}"
	qset "SAME_LAST_BRANCH" "${SAME_LAST_BRANCH}"
	qset "SAME_LAST_PROC" "${SAME_LAST_PROC}"
}

main
