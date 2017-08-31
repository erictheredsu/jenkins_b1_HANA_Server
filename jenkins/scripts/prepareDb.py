# -*- coding: utf-8 -*-
#this file should save as UTF-8
#Analytics TA prepare DB script
import os
import sys
import logging
import shutil
import time
from datetime import date

#environment variables
#HDB_HOST
#HDB_INST
#HDB_USR
#HDB_PWD
#SBOTESTUS  ## 0 skip, 1 create
#SBOTESTCN
#SBOTESTDE
#WS_CLIENT_PATH
#UPG_DB_NAME  ## for upgrade

dictLocale = {'US':{'DEFAULTLANG':3, 'NAME':'SBOTESTUS', 'DBNAME':'SBOTESTUS', 'COAKEY':'C,US_CoA'}, 'CN':{'DEFAULTLANG':15, 'NAME':'SBOTESTCN', 'DBNAME':'SBOTESTCN', 'COAKEY':'S, 小企业会计准则'}, 'DE':{'DEFAULTLANG':9, 'NAME':'SBOTESTDE', 'DBNAME':'SBOTESTDE', 'COAKEY':'M,DE_IKR'} }
defaultLocale = 'US'
logPath=os.path.join(os.environ['WORKSPACE'], "logs")
logFile = os.path.join(logPath, "TA_createDB_build#" + os.environ['BUILD_NUMBER'] + ".log")

def main():
  initLog()
  if sys.argv[1] == "upgrade":
    upgradeSBOCOMMONDB()
    upgradeCompanyDB()
  else:
    createCompanyDB()
  
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

def createCompanyDB():
  logging.debug('start create company')
  logging.debug('pre-testing...')
  if preTest() == False:
    doException('pre-test failed')
    return -1
    
  logging.debug('pre-testing done')
  
  #dbcredFilePath = createDbcredFile()
  
  #create US, DE, CN if required
  if os.environ.has_key('SBOTESTUS') and os.environ['SBOTESTUS'] == 'true':
    createCompanyDBwithLocal('US')
    
  if os.environ.has_key('SBOTESTCN') and os.environ['SBOTESTCN'] == 'true':
    createCompanyDBwithLocal('CN')
    
  if os.environ.has_key('SBOTESTDE') and os.environ['SBOTESTDE'] == 'true':
    createCompanyDBwithLocal('DE')
  
  logging.debug('company create done')
  
def createCompanyDBwithLocal(local):
  logging.debug('start create company: SBOTEST' + local)
  iniFile = createCompanyIniFile(local)
  
  cmdStr = r'%s\x64\Upgrade.exe %s COMMAND:CreateNewCompany;PARAMETERFILE:%s' % (os.environ['WS_CLIENT_PATH'], iniFile, iniFile)
  logging.debug('create Company DB\nExecuting:' + cmdStr)
  
  result = os.system(cmdStr)
  if result != 0:
    doException('failed to create company DB with exit code:%d' % result)
  else:
    logging.debug('company SBOTEST' + local + ' created')
    
def preTest():
  bRes = True
  if os.environ.has_key('HDB_HOST') == False:
    bRes = False
    doException('environment variable HDB_HOST is required')
    
  if os.environ.has_key('HDB_INST') == False:
    bRes = False
    doException('environment variable HDB_INST is required')

  if os.environ.has_key('HDB_USR') == False:
    bRes = False
    doException('environment variable HDB_USR is required')

  if os.environ.has_key('HDB_PWD') == False:
    bRes = False
    doException('environment variable HDB_PWD is required')

  if os.environ.has_key('WS_CLIENT_PATH') == False:
    bRes = False
    doException('environment variable WS_CLIENT_PATH is required')

  return bRes
  
def createDbcredFile():
  logging.debug('start create dbcred.txt')
  filePath = os.path.join(os.environ['WS_CLIENT_PATH'], 'x64\dbcred.txt')
  dbcred = open(filePath, 'w')
  dbcred.write('DBServer=' + os.environ['HDB_HOST'] + ':3' + os.environ['HDB_INST'] + '15\n')
  dbcred.write('DBType=9\n')
  dbcred.write('DBUser=' + os.environ['HDB_USR'] + '\n')
  dbcred.write('DBPassword=' + os.environ['HDB_PWD'] + '\n')
  dbcred.close()
  logging.debug('dbcred.txt created')
  return os.path.abspath(filePath)

def createCompanyIniFile(loc):
  logging.debug('start create company.ini')
    
  today = date.today()
  currYear = today.year
  if dictLocale.has_key(loc):
    lang = dictLocale[loc]['DEFAULTLANG']
    coakey = dictLocale[loc]['COAKEY']
    name = dictLocale[loc]['NAME']
    dbname = dictLocale[loc]['DBNAME']
  else:
    lang = dictLocale[defaultLocale]['DEFAULTLANG']
    coakey = dictLocale[defaultLocale]['COAKEY']
    name = dictLocale[defaultLocale]['NAME']
    dbname = dictLocale[defaultLocale]['DBNAME']
  
  filePath = os.path.join(os.environ['WS_CLIENT_PATH'], 'x64\company.ini')
  iniFile = open(filePath, 'w')
  iniFile.write('CREATE_USING_Package=False;\n')
  iniFile.write('DB_TYPE=9;\n')
  iniFile.write('DB_SERVER=' + os.environ['HDB_HOST'] + ':3' + os.environ['HDB_INST'] + '15;\n')
  iniFile.write('DB_USER=' + os.environ['HDB_USR'] + ';\n')
  iniFile.write('DB_PASSWORD=' + os.environ['HDB_PWD'] + ';\n')
  iniFile.write('NEWCOMPANYNAME=' + name + ';\n')
  iniFile.write('NEWDBNAME=' + dbname + ';\n')
  s = 'PERIODSTARTDATE={0}0101;\nCOUNTRY={1};\nDEFAULTLANG={2};\nPERIODSUBTYPE=M;\nPERIODENDDATE={0}1231;\nPERIODNUM=12;\nPERIODNAME={0};\nPERIODCODE={0};\nCOAKEY={3};'.format(currYear, loc, lang, coakey)
  iniFile.write(s) 
  iniFile.close()
  logging.debug('company.ini created')
  return os.path.abspath(filePath)

def upgradeCompanyDB():
  logging.debug('start upgrade company')
  logging.debug('pre-testing...')
  if preTest() == False:
    doException('pre-test failed')
    return -1
    
  logging.debug('pre-testing done')

  cmdStr = r'%s\Wizard\Upgrade.exe -Server %s -DbServerType 9 -DbUserName SYSTEM -DbPassword %s -CompanyDB %s' % (os.environ['WS_CLIENT_PATH'], os.environ['HDB_HOST'] + ':3' + os.environ['HDB_INST'] + '15', os.environ['HDB_PWD'], os.environ['UPG_DB_NAME'])
  logging.debug('upgrade Company DB\nExecuting:' + cmdStr)
  
  result = os.system(cmdStr)
  if result != 0:
    doException('failed to upgrade company DB with exit code:%d' % result)
  else:
    logging.debug('company ' + os.environ['UPG_DB_NAME'] + ' upgrade successful')
  
  logging.debug('company upgrade done')

def upgradeSBOCOMMONDB():
  logging.debug('start upgrade sbocommon')
  logging.debug('pre-testing...')
  if preTest() == False:
    doException('pre-test failed')
    return -1
    
  logging.debug('pre-testing done')

  cmdStr = r'%s\Wizard\Upgrade.exe -Server %s -DbServerType 9 -DbUserName SYSTEM -DbPassword %s -UpgradeComponent Common' % (os.environ['WS_CLIENT_PATH'], os.environ['HDB_HOST'] + ':3' + os.environ['HDB_INST'] + '15', os.environ['HDB_PWD'])
  logging.debug('upgrade SBOCOMMON DB\nExecuting:' + cmdStr)
  
  result = os.system(cmdStr)
  if result != 0:
    doException('failed to upgrade SBOCOMMON DB with exit code:%d' % result)
  else:
    logging.debug('sbocommon upgrade successful')
  
  logging.debug('sbocommon upgrade done')

def clean():
  build_path=os.path.join(os.environ['WORKSPACE'], os.environ['BUILD_NUMBER'])
  logging.debug('clean workspace: ' + build_path)
  shutil.rmtree(build_path, ignore_errors=True)

def doException(msg):
  raise Exception(msg)
  logging.exception(msg)
  
if __name__=="__main__":
  try:
    main()
  except:
    logging.exception("prepare company db failed!!")
    raise
  finally:
    clean()