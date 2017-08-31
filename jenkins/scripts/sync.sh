#!/bin/bash
#
#	sync artifacts to jenkins server
#

curl "http://10.58.121.144:60000/jenkins/job/SYNC_SCRIPTS/build?delay=0sec" -X POST
curl "http://10.58.121.141:60000/jenkins/job/SYNC_SCRIPTS/build?delay=0sec" -X POST