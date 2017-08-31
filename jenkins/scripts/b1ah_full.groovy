/*!
 *	B1AH Sanity Test Workflow
 */

// preinstall SLD/SBOCOMMON/COMPANY/OBS
def preInstall = { ->
	def success = true

	// cleanup all (b1 and db)
	invoke(SHELL_LINUX, "lib_cleanup_all.sh")

	// install SLD, SBOCOMMON, XApp, B1AH, Extention Manager and Service Layer
	//
	// returns
	// 		JOB_RESULT -> true/false
	args.INSTALL_TYPE = "ALL"
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

def initArtifacts = { ->
	new File("jmx_changes", CURRENT_SPACE).write("<table><tr><td>Sync hasn't been started</td></tr></table>")
	new File("results", CURRENT_SPACE).write("<table><tr><td>Test hasn't been performed</td></tr></table>")
}

def syncJmx = { ->

	def bmap = [
		"dev": 		"9.1",
		"9.1_DEV": 	"9.1",
		"9.1_COR": 	"9.1",
		"9.01_DEV": "9.01",
		"9.01_COR": "9.01"
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
				
		args.BUILDS_POOL = "${env.BUILD_SPACE}/full"
		args.BUILD_MARK = "${env.BUILD_SPACE}/full"
		BUILDS_POOL = args.BUILDS_POOL
		BUILD_MARK = args.BUILD_MARK
		
		// init artifacts for email
		initArtifacts()
		
		// check build
		args.BUILD_PKG = checkBuild(args.BRANCH)
		
		// check if there is a new build available
		invoke(SHELL_LINUX, "lib_check_build.sh")
		assert args.HAS_NEW_BUILD != null
		assert args.NEW_BUILD_PATH != null
		assert args.PREV_BUILD_PATH != null
		
		if (!args.HAS_NEW_BUILD.toBoolean()) {
			out.println "==== there is no new build ====" 
			build.result = hudson.model.Result.ABORTED
			return
		} 


		// a new build is now available
		out.println "==== a new build is now available ====" 
		out.println "NEW build: ${args.NEW_BUILD_PATH}" 
		args.BUILD_PATH = "${args.BUILDS_POOL}/${args.BRANCH}/new"
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
		} 
		
		// reboot HDB instance
		invoke(SHELL_LINUX, "lib_reboot_hana.sh")
		
		// sync jmx scripts
		syncJmx()
		
		// force restart obs before running jmeter
		invoke(SHELL_LINUX, "lib_restart_sl.sh")
		//invoke(SHELL_WIN32, "lib_restart_obs.bat", args.SLAVE_WIN32)
		
		// run b1ah and xapp jmx
		runjmx "SC_B1AH_Full"
		
		// force restart obs after running jmeter
		//invoke(SHELL_WIN32, "lib_restart_obs.bat", args.SLAVE_WIN32)
		
		//In this work flow, only jmeter run.
		analyzeResponsibility(BUILD_NUMBER,null,["SC_B1AH_Full"])
	    
		// copy result to workspace
		saveEnv()
		
		// display each job invocation elapsed
		showTimeline()	
		
		
		// emit final build result according to test result
		if (args.TEST_STATE == "unstable") {
			out.println "JMeter test case failed, mark build to 'unstable'"
			build.result = hudson.model.Result.UNSTABLE
		}
		
	}
	finally {
		if(getSlave){
			args.SLAVE_ACTION = "R"
			invoke(SHELL_LINUX, "lib_slave_pool.sh", "master")
		}
	}
}

// call main
main()