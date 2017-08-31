#!/bin/bash
. ${0%/*}/lib_core.sh

#WORKSPACE=/tmp
#HDB_HOST=10.58.114.78
#HDB_USR=SYSTEM
#HDB_PWD=manager
#export PATH=$PATH:/home/jenkins/tools/jdk/bin:/home/jenkins/tools/apache-jmeter-2.11/bin/

function main() {
	echo "#### Import license"
	JOB_RESULT=true
	free && sync && echo 3 > /proc/sys/vm/drop_caches && free	

	LIC_FILE="/lic/${HDB_HOST}.txt"
	if [ ! -f ${LIC_FILE} ]; then
		echo "#### No license file found ${LIC_FILE}"
		JOB_RESULT=false
	    qset "JOB_RESULT" "$JOB_RESULT"
		exit 1
	fi

	JMX_CASE_FILE="/home/jenkins/tools/artifacts/scripts/SC_License.jmx"
	TEST_PROP="${WORKSPACE}/sp_env.properties"
	HR_FILE="${WORKSPACE}/sp_env.hr"

	HDB_INST=${HDB_HOST}
	HDB_USR=${HDB_USR}
	HDB_PWD=${HDB_PWD}
	SCHEMA=SBOTESTUS
	SLD_HOST=${HDB_HOST}
	SLD_PORT=40000
	B1_USR=manager
	B1_PWD=manager
	SITE_USR=B1SiteUser
	SITE_PWD=1234
	B1AH_HOST=${HDB_HOST}
	B1AH_PORT=40000
	

	rm -rf $TEST_PROP
	touch $TEST_PROP
	echo "HDB_HOST=${HDB_HOST}" >> $TEST_PROP
	echo "HDB_INST=${HDB_INST}" >> $TEST_PROP
	echo "HDB_USR=${HDB_USR}" >> $TEST_PROP
	echo "HDB_PWD=${HDB_PWD}" >> $TEST_PROP
	echo "SLD_HOST=${SLD_HOST}" >> $TEST_PROP
	echo "SLD_PORT=${SLD_PORT}" >> $TEST_PROP
	echo "SCHEMA=${SCHEMA}" >> $TEST_PROP
	echo "B1_USR=${B1_USR}" >> $TEST_PROP
	echo "B1_PWD=${B1_PWD}" >> $TEST_PROP
	echo "SITE_USR=${SITE_USR}" >> $TEST_PROP
	echo "SITE_PWD=${SITE_PWD}" >> $TEST_PROP
	echo "LIC_FILE=${LIC_FILE}" >> $TEST_PROP
	echo "B1AH_HOST=${B1AH_HOST}" >> $TEST_PROP
	echo "B1AH_PORT=${B1AH_PORT}" >> $TEST_PROP
	echo "HR_FILE=${HR_FILE}" >> $TEST_PROP

	rm -f ${HR_FILE}
	jmeter -n -t "${JMX_CASE_FILE}" -p ${TEST_PROP}
	if [ ! -f "${HR_FILE}" ]; then
		echo "#### JMX case got failed"
		JOB_RESULT=false
	        qset "JOB_RESULT" "$JOB_RESULT"
		exit 1
	fi
	rm -f ${HR_FILE}
	qset "JOB_RESULT" "$JOB_RESULT"
}
main
