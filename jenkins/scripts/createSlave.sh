#!/bin/bash
SINGLE_WS=$WORKSPACE/$BUILD_NUMBER
rm -rf $SINGLE_WS
mkdir -p $SINGLE_WS 
if [ -z $IP_ADDRESS ]; then
	echo "Please input IP of the slave"
    exit 1
fi
if [ -z $PWD_ROOT ]; then
	echo "Please input password of root for the slave"
    exit 1
fi
export CHECK="ONLINE"
export TEST_PROP="$SINGLE_WS/test.properties"
export HR_FILE="$SINGLE_WS/hr"
rm -rf $HR_FILE
rm -rf $TEST_PROP
touch $TEST_PROP
echo "CI_HOST=${LOCAL_HOST}" >> $TEST_PROP
echo "CI_PORT=${LOCAL_HOST_PORT}" >> $TEST_PROP
echo "CI_USR=${LOCAL_HOST_USER}" >> $TEST_PROP
echo "CI_PWD=${LOCAL_HOST_PWD}" >> $TEST_PROP
echo "SLAVE_HOST=${IP_ADDRESS}" >> $TEST_PROP
echo "SLAVE_USR=root" >> $TEST_PROP
echo "SLAVE_PWD=${PWD_ROOT}" >> $TEST_PROP
pushd $SINGLE_WS
jmeter -n -t "$WORKSPACE/$BRANCH/jenkins/slave/CheckSlave.jmx" -p $TEST_PROP
HR_RST=$(cat $HR_FILE | awk "NR==1" | awk '{print $1}')
if [ $HR_RST != "$CHECK" ]; then
#Expect script
/usr/bin/expect -<<EOD
set timeout 10
spawn ssh root@$IP_ADDRESS
expect {
"*yes/no" { send "yes\r"; exp_continue }
"Password: " { send "$PWD_ROOT\r" }
}
expect "*#*"; send "mkdir -p $TOOLS_HOME\r"
expect "*#*"; send "exit\r"
expect eof
EOD
/usr/bin/expect -<<EOD
set timeout -1
spawn scp -r $TOOLS_HOME/jdk root@$IP_ADDRESS:$SLAVE_HOME
expect {
"*yes/no" { send "yes\r"; exp_continue }
"Password: " { send "$PWD_ROOT\r" }
}
expect eof
EOD
/usr/bin/expect -<<EOD
set timeout -1
spawn scp -r $TOOLS_HOME/rar root@$IP_ADDRESS:$TOOLS_HOME
expect {
"*yes/no" { send "yes\r"; exp_continue }
"Password: " { send "$PWD_ROOT\r" }
}
expect eof
EOD
/usr/bin/expect -<<EOD
set timeout -1
spawn scp -r $TOOLS_HOME/hdbclient_rev74 root@$IP_ADDRESS:$TOOLS_HOME
expect {
"*yes/no" { send "yes\r"; exp_continue }
"Password: " { send "$PWD_ROOT\r" }
}
expect eof
EOD
jmeter -n -t "$WORKSPACE/$BRANCH/jenkins/slave/CreateSlave.jmx" -p $TEST_PROP
HR_RST=$(cat $HR_FILE | awk "NR==1" | awk '{print $1}')
if [ $HR_RST != "$CHECK" ]; then
	echo "Failed to create slave..."
    exit 1
fi
fi
popd
rm -rf $SINGLE_WS