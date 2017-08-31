#!/bin/bash
FLAG="/opt/sap/SAPBusinessOne/B1_SHF/ServerTime.txt"
if [ $SP_ACTION == "R" ]; then
	rm -rf ${FLAG}
elif [ $SP_ACTION == "G" ]; then
	touch ${FLAG}
	DATETIME=$(date +%Y-%m-%d%t%X)
	echo $DATETIME >  ${FLAG}
else
	echo "Wrong action!!"
	exit 1
fi
