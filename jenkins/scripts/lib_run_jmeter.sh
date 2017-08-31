#!/bin/bash
#
#	run the specifc jmeter test case
#

# import the libs
. ${0%/*}/lib_core.sh


#
# entry point
#
function main() {

	# clear memory
	free && sync && echo 3 > /proc/sys/vm/drop_caches && free

	JMX_PATH=$JMX_ROOT_PATH/TestAutomation_B1/B1_HANAInnovation_DEV/$TEST_BRANCH

	#HOST_NAME=`echo ${HDB_HOST} | tr '[A-Z]' '[a-z]'`
	LIC_FILE="/lic/${HDB_HOST}.txt"
	TEST_PROP="test.properties"
	HR_FILE="hr"
	SLD_HOST=${HDB_HOST}
	SLD_PORT=40000
	B1_USR=manager
	B1_PWD=manager
	SITE_USR=B1SiteUser
	SITE_PWD=1234
	B1AH_HOST=${HDB_HOST}
	B1AH_PORT=40000
	OBS_HOST=${SLAVE_WIN32}
	OBS_PORT=60000
	SL_HOST=${HDB_HOST}
	SL_PORT=50000	
	if [ ! -f "$LIC_FILE" ]; then
		echo "######################### No license file found under /lic"
	    exit 1
	fi

	TEST_NAME=${JMX_FILE%.jmx}

	#rm -rf "$WORKSPACE/temp"
	mkdir -p "${WORKSPACE}/${BUILD_NUMBER}"
	pushd "${WORKSPACE}/${BUILD_NUMBER}"

	#"$WORKSPACE/SBO/dev/Components/XApp/Framework/test/CI/jmeter/scenario"
	rm -rf $TEST_PROP
	touch $TEST_PROP
	echo "HDB_HOST=${HDB_HOST}" >> $TEST_PROP
	echo "HDB_INST=${HDB_INST}" >> $TEST_PROP
	echo "HDB_USR=${HDB_USR}" >> $TEST_PROP
	echo "HDB_PWD=${HDB_PWD}" >> $TEST_PROP
	echo "SLD_HOST=${SLD_HOST}" >> $TEST_PROP
	echo "SLD_PORT=${SLD_PORT}" >> $TEST_PROP
	echo "SCHEMA=${TEST_COMP_DB:=SBOTESTUS}" >> $TEST_PROP
	echo "SCHEMA2=SBOTESTCN" >> $TEST_PROP
	echo "SCHEMA3=SBOTESTDE" >> $TEST_PROP
	echo "B1_USR=${B1_USR}" >> $TEST_PROP
	echo "B1_PWD=${B1_PWD}" >> $TEST_PROP
	echo "SITE_USR=${SITE_USR}" >> $TEST_PROP
	echo "SITE_PWD=${SITE_PWD}" >> $TEST_PROP
	echo "LIC_FILE=${LIC_FILE}" >> $TEST_PROP
	echo "B1AH_HOST=${B1AH_HOST}" >> $TEST_PROP
	echo "B1AH_PORT=${B1AH_PORT}" >> $TEST_PROP
	echo "OBS_HOST=${OBS_HOST}" >> $TEST_PROP
	echo "OBS_PORT=${OBS_PORT}" >> $TEST_PROP
	echo "SL_HOST=${SL_HOST}" >> $TEST_PROP
	echo "SL_PORT=${SL_PORT}" >> $TEST_PROP
	echo "JMX_XML2JSON=${JMX_PATH}/lib_jmx_xml2json.js" >> $TEST_PROP
	echo "JMX_XML2JSON_PY=${JMX_PATH}/lib_jmx_xml2json.py" >> $TEST_PROP
	echo "JMX_MDX_GROOVY=${JMX_PATH}/lib_jmx_mdx.groovy" >> $TEST_PROP
	echo "P4_ROOT_PATH=${P4_ROOT_PATH}" >> $TEST_PROP

	# copy jmx from remote server? no
	if [ -z "${JMX_CASE_FILE}" ]; then
		JMX_CASE_FILE=${JMX_PATH}/scenario/${JMX_FILE}
	fi
	jmeter -n -t "${JMX_CASE_FILE}" -p $TEST_PROP
	if [ "${EXIT_WITH_FAILED}" == "true" ]; then
		HR_RST=$(cat ${HR_FILE} | awk "NR==1" | awk '{print $1}' | tr -d " ")
		if [ "${HR_RST}" != "1" ]; then
			echo "######################### JMX case got failed"
			JOB_RESULT=false
		fi
		qset "JOB_RESULT" "$JOB_RESULT"
	else
		xsltproc "${JMX_PATH}/JMeterLogParser.xsl" ${TEST_NAME}.jtl -o ${TEST_NAME}.html || :
		TEST_RESULT="${PWD}/${TEST_NAME}.jtl"
		TEST_HTML="${PWD}/${TEST_NAME}.html"
		qset "TEST_RESULT" "${TEST_RESULT}"
		qset "TEST_HTML" "${TEST_HTML}"
	fi
	# qset "TEST_STATE" "success"

	#RST=$?
	#f [ $RST -ne 0 ]; then
	#	echo "Error occurs during test result trasformation: $RST"
	#fi
	popd
	#exit $RESULT
}

main

