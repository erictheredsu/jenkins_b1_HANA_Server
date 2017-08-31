#!/bin/bash
#
#	Restart Service Layer
#

# import the libs
. ${0%/*}/lib_core.sh

#
# entry point
#
function replaceB1Sconf() {
	conf_file="/opt/sap/SAPBusinessOne/ServiceLayer/b1s/modules/b1s.conf"
	ownergroup=`ls -l ${conf_file}  | awk '{print $3":"$4}'`
	mv "${conf_file}" "${conf_file}.bk"
	cp -f "${TOOLS_HOME}/artifacts/scripts/b1s.conf" "${conf_file}"
	chown ${ownergroup} ${conf_file}
}

function main() {
	/etc/init.d/b1s stop || :
	if [ "${B1S_CONF_REPLACEMENT}" == "true" ]; then
		replaceB1Sconf
	fi
	RESULT=1
	count=0
	until [ "${RESULT}" -eq "0" ] || [ "${count}" -eq "10" ]; do
        /etc/init.d/b1s start
        sleep 3
 		curl "https://localhost:50000/b1s/docs/v1/" -k -o api.html
        RESULT=$?
        let count="${count}+1"
    done
    if [ "${RESULT}" -eq "0" ]; then
		echo "Service Layer restarted"
	else
		echo "Service Layer restarted failed"
	fi
}

main

