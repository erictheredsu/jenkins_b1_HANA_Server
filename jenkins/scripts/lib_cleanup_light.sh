#!/bin/bash
#
#	cleanup light (b1, db - sbocommon, common, slddata...)
#

# const variables
BACKUP_TYPE="clean"

# import the libs
. ${0%/*}/lib_core.sh
. ${0%/*}/lib_db.sh
. ${0%/*}/lib_b1.sh

#
# entry point
#
function main() {
	# cleanup prev b1 installation if any
	swipe_b1
	# cleanup db to initial state
	swipe_db
}

main

