#!/bin/bash
echo $HDB_INST
echo $HDB_USR
echo $HDB_PWD
export HDB_SID="H${HDB_INST}"
export HDB_ADM_PWD="Initial0"
export JOB_RESULT=false
rm -rf /var/tmp/*
free && sync && echo 3 > /proc/sys/vm/drop_caches && free
proc=$(ps aux | grep -v grep | grep HDB00 | wc -l)
if [ $proc -gt 0 ]; then
	hana_path=$(ps aux | grep -v grep | grep HDB00 | grep sapstartsrv | sed s#HDB${HDB_INST}/exe/sapstartsrv.*## | grep -v sed | awk '{print $NF}')
	hana_uninstall=${hana_path}SYS/global/hdb/install/bin/hdbuninst
	if [ `ls $hana_uninstall` ]; then
	 	${hana_uninstall} --batch
	else
		echo "Cannot find the installed HANA instance's uninstaller"
		exit 1
	fi
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
        	exit $RESULT
	fi
fi
free && sync && echo 3 > /proc/sys/vm/drop_caches && free
pushd /home/CurrentHANA/SAP_HANA_DATABASE
./hdbinst --batch \
--ignore=check_platform,check_hardware \
--system_usage=custom \
--sapmnt=/hana/shared \
--sid=${HDB_SID} \
--number=${HDB_INST} \
--home=/usr/sap/${HDB_SID}/home \
--shell=/bin/sh \
--datapath=/hana/shared/${HDB_SID}/global/hdb/data \
--logpath=/hana/shared/${HDB_SID}/global/hdb/log \
--password ${HDB_ADM_PWD} \
--system_user_password ${HDB_PWD}
RESULT=$?
if [ $RESULT -ne 0 ]; then
	exit $RESULT
fi
popd
free && sync && echo 3 > /proc/sys/vm/drop_caches && free
pushd /home/CurrentHANA/SAP_HANA_AFL
./hdbinst --batch --sid=${HDB_SID}
RESULT=$?
if [ $RESULT -ne 0 ]; then
        exit $RESULT
fi
popd
/usr/sap/hdbclient/hdbsql \
-i ${HDB_INST} \
-u ${HDB_USR} \
-p ${HDB_PWD} \
-a -x -j "alter system alter configuration ('daemon.ini','SYSTEM') set ('scriptserver','instances')='1' with reconfigure"
RESULT=$?
if [ $RESULT -ne 0 ]; then
        exit $RESULT
fi
JOB_RESULT=true
exit 0
