#!/bin/bash
#
#	backup db
#

# import the libs
. ${0%/*}/lib_core.sh
. ${0%/*}/lib_db.sh


#
# entry point
#
function main() {
	export -p | grep HDB
	
	# backup db
	backup
}

main

