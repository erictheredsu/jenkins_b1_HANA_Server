#!/bin/bash
#
#	build b1ah and xapp, make RPM package
#

# env
export PATH=${PATH}:${TOOLS_HOME}/apache-ant-1.8.2/bin:${TOOLS_HOME}/node-v0.10.28-linux-x64/bin
export JAVA_HOME=${TOOLS_HOME}/jdk
export SRC_DIR=${P4_ROOT_PATH}/BUSMB_B1/SBO/${BRANCH}/Source/Infrastructure
export OUTPUT_DIR=${P4_ROOT_PATH}/${BRANCH}/bin
export RPM_OUTPUT_PATH=${P4_ROOT_PATH}/${BRANCH}/rpm

# import the libs
. ${0%/*}/lib_core.sh
. ${0%/*}/build.sh
. ${0%/*}/build_rpm.sh

#
# entry point
#
function main() {

	# compile and build rpm
	buildB1AH
	buildRPM
	if [ $? -ne 0 ]; then
		echo "failed to compile and make RPM package"
		exit 1
	fi

	# copy the rpm to the build path
	cp ${RPM_OUTPUT_PATH}/* ${BUILD_PATH}/${INSTALLER_PKG_NAME}/ServerComponents/RPM/
}

main

