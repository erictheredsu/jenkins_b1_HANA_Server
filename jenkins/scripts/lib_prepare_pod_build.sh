#!/bin/bash
#
#	install SLD, SBOCOMMON, XApp and B1AH with POD packages
#

# import the libs
. ${0%/*}/lib_core.sh

function main() {
	cp -f "${BUILDS_POOL}/${BRANCH}/prev/${INSTALLER_PKG_NAME}/ServerComponents/ZIP/"*.zip "${BUILD_PATH}/${INSTALLER_PKG_NAME}/ServerComponents/ZIP/"
	# check result
	if [ $? -ne 0 ]; then
		exit $?
	fi
}
main
