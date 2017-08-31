#Analytics TA prepare OBServer script
from P4 import P4, P4Exception
import logging
import os
import shutil
import socket
import time

#sys vars
#TOOL_ANT
#CATALINA_HOME
#BRANCH
#BUILD_NUMBER
#WORKSPACE

#local vars
hostname=socket.gethostname()
P4_CLENT='CI_' + hostname
P4_ROOT=r'c:\tmp\p4\CI'
P4_PORT='perforce3230.wdf.sap.corp:3230'
P4_USER='b1local'
P4_PASSWD='localPW4B1'
B1CLIENT_PATH=r'c:\tmp\b1client'
B1OBS_LIB_PATH=B1CLIENT_PATH + r'\x64\DIAPI_90\SAPbobsCOM90.dll'
TOMCAT_SERVICE_NAME='tomcat'
OBS_PATH=r'c:\tmp\tomcat\webapps\obs'
OBS_WAR_PATH=r'c:\tmp\tomcat\webapps\obs.war'
SOURCE_PATH=r'%s\BUSMB_B1\TestAutomation_B1\B1_HANAInnovation_DEV\jenkins\utility\obs'% P4_ROOT
BUILD_OUTPUT_PATH=r'%s\obs.war' % SOURCE_PATH

os.environ['OBS_LIB']=B1CLIENT_PATH + r'\x64\DIAPI_90'

logPath=os.path.join(os.environ['WORKSPACE'], "logs")
logFile = os.path.join(logPath, "TA_OBServerCloud_build#" + os.environ['BUILD_NUMBER'] + ".log")

def initLog():
  if os.path.exists(logPath) == False:
    os.makedirs(logPath)
  
  logging.basicConfig(
    level    = logging.DEBUG,
    format   = '%(asctime)s %(levelname)-8s line#%(lineno)-4d  %(message)s',
    datefmt  = '',
    filename = logFile,
    filemode = 'w')
    
  # define a Handler which writes INFO messages or higher to the sys.stderr
  console = logging.StreamHandler()
  console.setLevel(logging.DEBUG)
  # set a format which is simpler for console use
  formatter = logging.Formatter('%(levelname)-8s line#%(lineno)-4d  %(message)s')
  # tell the handler to use this format
  console.setFormatter(formatter)
  # add the handler to the root logger
  logging.getLogger('').addHandler(console)
    
def main():
  initLog()
  prepareOBS()
  
def prepareOBS():
  killB1Process()
  handleTempFolder()
  
  logging.debug("stop tomcat...")
  runSysCommand('net stop ' + TOMCAT_SERVICE_NAME)
  
  handleB1Client()
  
  syncCode()
  buildOBS()
  deployOBS()

def deployOBS():
  logging.debug("deploy OBS...")

  # remove old OBS, below step must after tomcat stop
  if os.path.exists(OBS_PATH) == True:
    shutil.rmtree(OBS_PATH)

  if os.path.exists(OBS_WAR_PATH) == True:
    os.remove(OBS_WAR_PATH)
  shutil.copyfile(BUILD_OUTPUT_PATH, OBS_WAR_PATH)
  runSysCommand('net start ' + TOMCAT_SERVICE_NAME, True)

def handleB1Client():
  logging.debug("handle B1 client...")
  logging.debug("un-register OBServer...")
  runSysCommand('regsvr32 -s -u ' + B1OBS_LIB_PATH)
  logging.debug("remove old B1 client folder...")

  #shutil.rmtree(B1CLIENT_PATH, ignore_errors=True)
  #try to remove b1 client folder
  #there is a bug, sometimes it cannot been deleted, so try multi times
  tryCount = 0
  maxTryCount = 30
  while os.path.exists(B1CLIENT_PATH):
    tryCount = tryCount + 1
    if tryCount > maxTryCount:
      msg = "cannot delete b1 client folder at %s" % B1CLIENT_PATH
      logging.debug(msg)
      raise Exception(msg)
      return -1

    time.sleep(1)
    runSysCommand('rd /s /q ' + B1CLIENT_PATH)

  logging.debug("extract latest B1 client")
  if os.path.exists(os.environ['BUILD_ZIP_FILE']) == False:
    msg = "B1 client zip file does not exist; please check environment variable BUILD_ZIP_FILE"
    logging.debug(msg)
    raise Exception(msg)
    return -1

  runSysCommand('%TOOL_7z% x %BUILD_ZIP_FILE% -aoa -o' + B1CLIENT_PATH + r' x64\Conf x64\DIAPI\90', True)
  # shutil.move(B1CLIENT_PATH + r'\x64\DIAPI\90', B1CLIENT_PATH + r'\x64\DIAPI_90')
  runSysCommand('rd /s /q ' + B1CLIENT_PATH + r'\x64\DIAPI_90')
  runSysCommand('dir ' + B1CLIENT_PATH + r'\x64\DIAPI_90')
  runSysCommand('move ' + B1CLIENT_PATH + r'\x64\DIAPI\90 ' + B1CLIENT_PATH + r'\x64\DIAPI_90', True)
  runSysCommand('dir ' + B1CLIENT_PATH + r'\x64\DIAPI_90')
  runSysCommand('regsvr32 -s ' + B1OBS_LIB_PATH, True)

def handleTempFolder():
  logging.debug("handle temp folder...")
  logging.debug("temp folder path: " + os.environ['temp'])
  shutil.rmtree(os.environ['temp'], ignore_errors=True)
  if os.path.exists(os.environ['temp']) == False:
    os.makedirs(os.environ['temp'])

  filePath = os.path.join(os.environ['temp'], 'b1_disable_eula_acceptance')
  tmpB1EULA = open(filePath, 'w')
  tmpB1EULA.close()
  if os.path.exists(filePath) == True:
    logging.debug("b1_disable_eula_acceptance create success, file path:" + filePath)
  else:
    msg = "b1_disable_eula_acceptance create fail"
    logging.debug(msg)
    raise Exception(msg)
  
def killB1Process():
  logging.debug("killB1Process...")
  runSysCommand('taskkill /f /im "SAP Business One.exe"')
  runSysCommand('taskkill /f /im "Upgrade.exe"')

def syncCode():
  logging.debug("syncCode...")
  if os.path.exists(P4_ROOT) == False:
    os.makedirs(P4_ROOT)
    
  p4 = P4()                        # Create the P4 instance
  p4.cwd = P4_ROOT
  p4.port = P4_PORT
  p4.user = P4_USER
  p4.password = P4_PASSWD
  p4.client = P4_CLENT

  try:                             # Catch exceptions with try/except
    p4.connect()                   # Connect to the Perforce Server
    p4.run_login()
    info = p4.run("info")          # Run "p4 info" (returns a dict)
    for key in info[0]:            # and display all key-value pairs
      logging.debug(key + " = " + info[0][key])
    
    client = p4.fetch_client()
    client[ "Description" ] = "New TA p4 client"
    client._root = P4_ROOT
    p4.save_client(client)
    
    oldPath = os.getcwd()
    os.chdir(P4_ROOT)
    logging.debug("run p4 force sync")
    p4.run("sync", "-f", "//BUSMB_B1/TestAutomation_B1/B1_HANAInnovation_DEV/jenkins/utility/obs/...")
    logging.debug("p4 sync done")
    os.chdir(oldPath)
  except P4Exception:
    for e in p4.errors:            # Display errors
      logging.debug(e)
    raise Exception('sync code failed')
  finally:
    p4.disconnect()
 
def buildOBS():
  logging.debug("start to build OBS Cloud")
  oldPath = os.getcwd()
  os.chdir(SOURCE_PATH)
  runSysCommand('%TOOL_ANT%', True)
  os.chdir(oldPath)
  logging.debug("build OBS Cloud done")

def runSysCommand(cmd, failToStop = False):
  logging.debug("running... cmd: " + cmd)
  ret = os.system(cmd)
  if ret == 0:
    logging.debug("successfully run system command: " + cmd)
  else:
    msg = "failed to run system command: " + cmd + ", " + str(ret)
    logging.debug(msg)
    if failToStop:
      raise Exception(msg)
  
if __name__=="__main__":
  try:
    main()
  except:
    logging.exception("prepare OBServer cloud failed!")
    raise