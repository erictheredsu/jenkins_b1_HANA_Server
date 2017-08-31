#!/bin/bash
#
#	basic function library
#

#echo "# arguments called with ---->  ${@}     "
#echo "# \$1 ---------------------->  $1       "
#echo "# \$2 ---------------------->  $2       "
#echo "# path to me --------------->  ${0}     "
#echo "# parent path -------------->  ${0%/*}  "
#echo "# my name ------------------>  ${0##*/} "

#
# export the variable to jenkins server
#
function qset() {
	local key=$1
	local value=$2
	echo "!!${key}=${value}"
}

#
# mark the lib import successfuly
#
function marklib() {
	echo "${0##*/} imported successfuly"
}

function exportTestEnv() {
    export SLD_HOST=${HDB_HOST}
    export SLD_PORT=40000
    export B1_USR=manager
    export B1_PWD=manager
    export SITE_USR=B1SiteUser
    export SITE_PWD=1234
    export B1AH_HOST=${HDB_HOST}
    export B1AH_PORT=40000
    export SL_HOST=${HDB_HOST}
    export SL_PORT=50000
    export P4_ROOT_PATH=/home/jenkins/workspace/SYNC_SOURCE
}

# mark
echo "lib_core.sh imported successfuly"