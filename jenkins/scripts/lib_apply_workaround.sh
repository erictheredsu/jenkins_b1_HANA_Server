#!/bin/bash
#
#	workaround to bypass the known issues
#

# import the libs
. ${0%/*}/lib_core.sh

function restartSLD() {
	/etc/init.d/sapb1servertools restart
	return $?
}

function changeOwner() {
	chown -R b1service0:b1service0 $DFT_INSTALL_DIR
	return $?
}

#
# entry point
#
function main() {
	changeOwner
	restartSLD
}

main

