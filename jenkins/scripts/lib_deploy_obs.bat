rem !cmd.exe
rem
rem	deploy obs cloud
rem

rem sys vars
rem TOOL_Python

hostname
rem set HDB

set JAVA_HOME=C:\Program Files\Java\jdk1.7.0_06
set TOOL_7z=C:\tmp\software\7Zip\7z.exe
set TOOL_Python=C:\Python26\python.exe
set TOOL_ANT=C:\tmp\software\apache-ant-1.9.3\bin\ant
set CATALINA_HOME=C:\tmp\tomcat

echo "start to prepare OBS Cloud\n"

%TOOL_Python% %~dp0\prepareOBS.py

if "%errorlevel%" EQU "0" (
	echo "prepare OBS Cloud success"
	echo !!JOB_RESULT=true
) else (
	echo "prepare OBS Cloud failed"
	echo !!JOB_RESULT=false
)

exit 0