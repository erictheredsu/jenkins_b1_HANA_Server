rem 
rem parameter new/upgrade
rem

set

set WS_CLIENT_PATH=%WORKSPACE%\%BUILD_NUMBER%\%BRANCH%
set UPG_DB_NAME=SBODEMOUS

IF "%~1" == "upgrade" (
    echo "upgrade sbocommon db and companydb"
    CALL:UpgradeDB
) ELSE (
    echo "create new company db"
    CALL:CreateNewCompany
)

GOTO:EOF

:CreateNewCompany
rmdir /q /s %WS_CLIENT_PATH%\x64

%TOOL_7z% x %BUILD_ZIP_FILE% -aoa -o%WS_CLIENT_PATH% x64

move %WS_CLIENT_PATH%\x64\"SAP Business One.exe" %WS_CLIENT_PATH%\x64\Upgrade.exe
GOTO:EOF

:UpgradeDB
rmdir /q /s %WS_CLIENT_PATH%\Wizard
xcopy %UPGRADER_ZIP_FILE%  %WS_CLIENT_PATH%\Wizard /S /I

GOTO:EOF