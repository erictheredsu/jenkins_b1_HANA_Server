#!/bin/bash
#
#	restore db
#
# parameters:
#
#	BACKUP_TYPE -> clean: restore db from ${HDB_INST_PATH}/jenkins/clean.[0-5]
#				-> base: restore db from ${HDB_INST_PATH}/jenkins/base.[0-5]
#

# import the libs
. ${0%/*}/lib_core.sh
. ${0%/*}/lib_db.sh


#
# entry point
#
function main() {
	export -p | grep HDB
	export -p | grep BACKUP_TYPE

	# restore db
	restore
}

main

