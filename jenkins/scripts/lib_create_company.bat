rem !cmd.exe
rem
rem	create b1 company
rem

hostname

set TOOL_7z=C:\tmp\software\7Zip\7z.exe
set TOOL_Python=C:\Python26\python.exe

echo "start prepare build\n"
echo "SCRIPT_PATH: "%SCRIPT_PATH%
if "%COMPANY_ACTION%" == "" set COMPANY_ACTION=new
call %~dp0\prepareBuild.bat %COMPANY_ACTION%
if "%errorlevel%" EQU "0" (
	echo "prepare build success"
) else (
	echo "prepare build failed"
	goto:eof
)

echo "start to create company db\n"

%TOOL_Python% %~dp0\prepareDb.py %COMPANY_ACTION%

if "%errorlevel%" EQU "0" (
	echo "create company db success\n"
	echo !!JOB_RESULT=true
) else (
	echo "create company db failed\n"
	echo !!JOB_RESULT=false
)

exit 0