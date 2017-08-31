rem !cmd.exe
rem
rem	restart obs
rem

net stop tomcat
net start tomcat
timeout 5

rem call x:\curl "http://localhost:60000/obs/" -X POST -H "Content-Type: text/plain" --data "json{echo 'cool'}"

echo obs server is working
exit 0