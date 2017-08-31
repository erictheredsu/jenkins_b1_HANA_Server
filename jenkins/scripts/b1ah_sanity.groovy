/*!
 *	B1AH Sanity Test Workflow
 */

// preinstall SLD/SBOCOMMON/COMPANY/OBS
def preInstall = { ->
	def success = true

	// cleanup all (b1 and db)
	invoke(SHELL_LINUX, "lib_cleanup_all.sh")

	// install SLD and SBOCOMMON only
	//
	// returns
	// 		JOB_RESULT -> true/false
	invoke(SHELL_LINUX, "lib_check_hdb_user.sh")
	assert args.JOB_RESULT.toBoolean()	
	args.INSTALL_TYPE = "BASE"
	invoke(SHELL_LINUX, "lib_install_server.sh")
	success = args.JOB_RESULT.toBoolean()

	// create a company
	//
	// returns
	// 		JOB_RESULT -> true/false
	if (success) {
		invoke(SHELL_WIN32, "lib_create_company.bat", args.SLAVE_WIN32)
		success &= args.JOB_RESULT.toBoolean()
	}

	// build and deploy obs cloud service
	//
	// returns
	// 		JOB_RESULT -> true/false
	//if (success) {
	//	invoke(SHELL_WIN32, "lib_deploy_obs.bat", args.SLAVE_WIN32)
	//	success &= args.JOB_RESULT.toBoolean()
	//}

	return success
}

def runjmx = { ...tc -> 
	tc.each {
		args.JMX_FILE = "${it}.jmx"
		args.TEST_NAME = it
		invoke(SHELL_LINUX, "lib_run_jmeter.sh", "master")	

		// copy result to workspace
		shell("cp ${args.TEST_RESULT} ${CURRENT_SPACE}/")
		shell("cp ${args.TEST_HTML} ${CURRENT_SPACE}/")		
	}

	out.println "Analyzing test results..."

	def finalState = true
	new File("results", CURRENT_SPACE).withWriter{ fs ->
		// header
		fs << "<table><tbody><tr><td class=\"fixed-width-label\">Module</td><td class=\"fixed-width-state\">State</td><td>Memo</td></tr>"
		tc.each {
			def tr = org.jsoup.Jsoup.parse(new File("${it}.html", CURRENT_SPACE).text).select("body > table:nth-child(5) > tbody > tr:nth-child(2)")
			def hr = (tr.attr("class") != "Failure")
			def state = (hr ? "success" : "unstable")
			def samples = tr.select("> td:nth-child(1)").text().toInteger()
			def failures = tr.select("> td:nth-child(2)").text().toInteger()
			def rate = tr.select("> td:nth-child(3)").text()

			finalState &= hr
			def rooturl = env.JENKINS_URL
			fs << "<tr><td>${it}<a href=\"${rooturl}job/${env.JOB_NAME}/ws/${BUILD_NUMBER}/${it}.html\"><img src=\"${rooturl}static/e59dfe28/images/16x16/linkicon.png\"/></a></td><td><img src=\"${rooturl}static/e59dfe28/images/16x16/${state}.png\"/></td><td>${samples - failures} out of $samples samples passed, success rate $rate</td></tr>"
		}
		// footer
		fs << "</tbody></table>"
	}

	args.TEST_STATE = (finalState ? "success" : "unstable")
}

def codeScan = { ->
	def ran = true
	def rs = invoke("CODE_SCAN", "code scan")
	def number = rs.build.number
	args.CODE_SCAN_NUMBER = number

	// grab the cs result
	def url = "${env.JENKINS_URL}job/CODE_SCAN/${number}/findbugsResult/"
	def doc = org.jsoup.Jsoup.connect(url).get()
	def high = doc.select("#HIGH>a").text()
	def normal = doc.select("#NORMAL>a").text()

	out.println "Code scan result -> high = $high"
	out.println "Code scan result -> normal = $normal"

	args.CODE_SCAN_HIGH = high
	args.CODE_SCAN_NORMAL = normal
}

def unitTest = { ->
	def rs = invoke('UnitTest_Coverage','')
	def number = rs.build.number

	//unit test result
	def urlUT = "${env.JENKINS_URL}job/UnitTest_Coverage/${number}/testReport/"
	def urlCoverage = "${env.JENKINS_URL}job/UnitTest_Coverage/lastBuild/jacoco/"

	def _docUT = org.jsoup.Jsoup.connect(urlUT).get()
	def utTestResult = _docUT.select("#main-panel>div>div").text().replaceAll("\\(.0\\) ", "in").replaceAll(/in$/, "");
	
	//coverage result, six items in list.
	def _docCoverage = org.jsoup.Jsoup.connect(urlCoverage).get()
	def elements = _docCoverage.select("td.data");

	new File("UTresults", CURRENT_SPACE).withWriter{ fs ->
		// header
		fs << "<table><tbody><tr>"
		fs << "<td class=\"fixed-width-label\">${utTestResult}</td><td>"
		fs << "<a href=\"${urlUT}\">${urlUT}</a></td></tr></tbody></table>"
		fs << "<table><tr>"
		fs << "<td class=\"fixed-width-label\">instruction</td>"
		fs << "<td class=\"fixed-width-label\">branch</td>"
		fs << "<td class=\"fixed-width-label\">complexity</td>"
		fs << "<td class=\"fixed-width-label\">line</td>"
		fs << "<td class=\"fixed-width-label\">method</td>"
		fs << "<td class=\"fixed-width-label\">class</td>"
		fs << "</tr><tr>"
		for(def i=0;i<6;i++){
			fs << "<td>${elements.get(i).text()}</td>"
		}
		fs << "</tr><tr><td colspan=998><a href=\"${urlCoverage}\">${urlCoverage}</a></td></tr>"
		fs << "</table>"
	}
	return rs;
}

def initArtifacts = { ->
	new File("changes", CURRENT_SPACE).write("<table><tr><td>Sync hasn't been started</td></tr></table>")
	new File("jmx_changes", CURRENT_SPACE).write("<table><tr><td>Sync hasn't been started</td></tr></table>")
	new File("results", CURRENT_SPACE).write("<table><tr><td>Test hasn't been performed</td></tr></table>")
	new File("UTresults", CURRENT_SPACE).write("<table><tr><td>Unit Test hasn't been performed</td></tr></table>")
	args.CODE_SCAN_NUMBER = 0
}

def sync = { ->

	def rs = invoke(SYNC_SOURCE, "")
	def changeSet = rs.build.changeSet

	new File("changes", CURRENT_SPACE).withWriter{ fs ->
		if (changeSet != null) {
			if (changeSet.isEmptySet()) {
				fs << "<table><tr><td>There is no change since the last build</td></tr></table>"
			} else {
				fs << "<table>"
				changeSet.each { cs ->		
					fs << "<tr><td class=\"fixed-width-label\">CL ${cs.commitId?:cs.revision?:cs.changeNumber} by ${cs.author}</td><td>${cs.msgAnnotated}<br/><br/>"				
					cs.affectedFiles.each { p ->
			        	fs << "${p.editType.name}: ${p.path}<br/>"
					}
					fs << "</td></tr>"
				}
				fs << "</table>"
			}				
		} else {
			fs << "<table><tr><td>Sync job was in malformed state</td></tr></table>"
		}		
	}

	args.P4_ROOT_PATH = rs.build.workspace
}

def syncJmx = { ->

	def bmap = [
		"dev": 		"9.1",
		"9.2_COR":	"9.2",
		"9.2_DEV":	"9.2",
		"9.1_DEV": 	"9.1",
		"9.1_COR": 	"9.1",
		"9.01_DEV": 	"9.01",
		"9.01_COR": 	"9.01"
	]

	args.TEST_BRANCH = bmap[args.BRANCH]
	def rs = invoke(SYNC_JMX, "sync jmx files", "master")
	def changeSet = rs.build.changeSet

	new File("jmx_changes", CURRENT_SPACE).withWriter{ fs ->
		if (changeSet != null) {
			if (changeSet.isEmptySet()) {
				fs << "<table><tr><td>There is no change since the last build</td></tr></table>"
			} else {
				fs << "<table>"
				changeSet.each { cs ->		
					fs << "<tr><td class=\"fixed-width-label\">CL ${cs.commitId?:cs.revision?:cs.changeNumber} by ${cs.author}</td><td>${cs.msgAnnotated}<br/><br/>"				
					cs.affectedFiles.each { p ->
			        	fs << "${p.editType.name}: ${p.path}<br/>"
					}
					fs << "</td></tr>"
				}
				fs << "</table>"
			}				
		} else {
			fs << "<table><tr><td>Sync job was in malformed state</td></tr></table>"
		}		
	}

	args.JMX_ROOT_PATH = rs.build.workspace
}

// entry point
def main = { ->
	def getSlave = false
	try{

		args.PROC_NAME = "${env.JOB_NAME}"
		args.SLAVE_ACTION = "O"
		invoke(SHELL_LINUX, "lib_slave_pool.sh", "master")
		getSlave = args.JOB_RESULT.toBoolean()
		if (!getSlave) {
			out.println "==== No available slave ====" 
			build.result = hudson.model.Result.ABORTED
			return
		} 
		
		// init artifacts for email
		initArtifacts()
		
		// check build
		args.BUILD_PKG = checkBuild(args.BRANCH)
		
		// check if there is a new build available
		//
		// returns
		// 		HAS_NEW_BUILD -> true/false
		//		NEW_BUILD_PATH -> \\10.58.6.49\builds_cn\SBO\dev\910.105.00_CNPVG50839504AV_SBO_EMEA_dev_030614_203930_1334938.HANA
		//		PREV_BUILD_PATH -> \\10.58.6.49\builds_cn\SBO\dev\910.105.00_CNPVG50839504AV_SBO_EMEA_dev_300514_065746_1334341.HANA
		invoke(SHELL_LINUX, "lib_check_build.sh")
		assert args.HAS_NEW_BUILD != null
		assert args.NEW_BUILD_PATH != null
		assert args.PREV_BUILD_PATH != null
		
		if (!args.HAS_NEW_BUILD.toBoolean() && args.SAME_LAST_BRANCH.toBoolean() && args.SAME_LAST_PROC.toBoolean()) {
			// there is no new build, continue test with prev build
			out.println "==== there is no new build, continue test with prev build ====" 
			out.println "PREV build: ${args.PREV_BUILD_PATH}"
			args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/prev"
			args.FULL_BUILD_PATH = args.PREV_BUILD_PATH
			
			// cleanup b1ah, xapp
			invoke(SHELL_LINUX, "lib_cleanup_b1ah.sh")
		
			// restore prev db
			args.BACKUP_TYPE = "base"
			invoke(SHELL_LINUX, "lib_restore_db.sh")
		} else if ( !args.HAS_NEW_BUILD.toBoolean() ) {
			args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/prev"
			args.FULL_BUILD_PATH = args.PREV_BUILD_PATH
		
			// preinstall the new build
			def success = preInstall()
			args.TEST_NEW_BUILD = success
		
			// check whether preinstall succeed or not
			if (success) {
				out.println "==== reinstall build successfully ====" 
		
				// back to prev build
				args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/prev"
		
				// backup db
				args.BACKUP_TYPE = "base"
				invoke(SHELL_LINUX, "lib_backup_db.sh")
			} else {
				out.println "==== reinstall build failed ====" 
				assert success
			}
		} else {
			// a new build is now available
			out.println "==== a new build is now available ====" 
			out.println "NEW build: ${args.NEW_BUILD_PATH}" 
			args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/new"
			args.FULL_BUILD_PATH = args.NEW_BUILD_PATH
		
			// preinstall the new build
			def success = preInstall()
			args.TEST_NEW_BUILD = success
		
			// check whether preinstall succeed or not
			if (success) {
				out.println "==== precheck build successfully ====" 
		
				// archive the build
				args.ARCHIVE_RESULT = true
				invoke(SHELL_LINUX, "lib_archive_build.sh")
		
				// back to prev build
				args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/prev"
		
				// backup db
				args.BACKUP_TYPE = "base"
				invoke(SHELL_LINUX, "lib_backup_db.sh")
			} else {
				out.println "==== precheck build failed ====" 
		
				// archive the build
				args.ARCHIVE_RESULT = false
				invoke(SHELL_LINUX, "lib_archive_build.sh")
		
				// back to prev build
				args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/prev"
				args.FULL_BUILD_PATH = args.PREV_BUILD_PATH
		
				// check if previous build exists or not
				//assert new File(args.BUILD_PATH).exists()
		
				// preinstall the prev build
				assert preInstall()
			}
		}
		
		// sync code
		sync()
		
		// the following args should not be null at this moment
		assert args.BUILD_PATH != null
		assert args.FULL_BUILD_PATH != null
		
		// build RPM (b1ah, xapp)
		invoke(SHELL_LINUX, "lib_b1ah_build.sh")
		
		// run code scan
		//codeScan()
		

		//def sld_status = shell("curl https://${args.HDB_HOST}:40000/ControlCenter/ --insecure > /dev/null")
		//if (sld_status != 0) {
		//	out.println 'error...'
		//	assert false
		//}
		invoke(SHELL_LINUX, "lib_check_hdb_user.sh")
		assert args.JOB_RESULT.toBoolean()	
		// install xapp and b1ah
		args.INSTALL_TYPE = "XA"
		invoke(SHELL_LINUX, "lib_install_server.sh")
		assert args.JOB_RESULT.toBoolean()	
		
		// apply workaround if any to bypass the known issues of product that impact TA
		invoke(SHELL_LINUX, "lib_apply_workaround.sh")
		
		// reboot HDB instance
		invoke(SHELL_LINUX, "lib_reboot_hana.sh")
		
		// sync jmx scripts
		syncJmx()
		
		// force restart obs before running jmeter
		invoke(SHELL_LINUX, "lib_restart_sl.sh")
		//invoke(SHELL_WIN32, "lib_restart_obs.bat", args.SLAVE_WIN32)
		
		// run b1ah and xapp jmx
		runjmx "SC_B1AH_Sanity", "SC_XApp_Sanity"
		//, "SC_SLD_Sanity"
		
		//f utResults = unitTest()		
		
		// force restart obs after running jmeter
		//invoke(SHELL_WIN32, "lib_restart_obs.bat", args.SLAVE_WIN32)
		
		// copy result to workspace
		saveEnv()

		//Define in lib_core.groovy
	    analyzeResponsibility(BUILD_NUMBER,0,["SC_B1AH_Sanity"])
	    
		// display each job invocation elapsed
		showTimeline()	
		
		
		// emit final build result according to test result
		if (args.TEST_STATE == "unstable") {
			out.println "JMeter test case failed, mark build to 'unstable'"
			build.result = hudson.model.Result.UNSTABLE
		}
	}catch(e)
	{
		out.println e;
	}
	finally	{
		if(getSlave){
			args.SLAVE_ACTION = "R"
			env.SLAVE_ACTION = "R"
			out.println "Try to release slave..."
			out.println env.SLAVE_ACTION
			invoke(SHELL_LINUX, "lib_slave_pool.sh", "master")
		}
	}
}

// call main
main()
