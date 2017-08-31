/*!
 *	B1AH Sanity Test Workflow
 */

// preinstall base build
def preInstall = { ->
	def success = true
	invoke(SHELL_LINUX, "lib_cleanup_all.sh")	
	invoke(SHELL_LINUX, "lib_install_server.sh")
	success = args.JOB_RESULT.toBoolean()
	return success
}

// upgrade to current build
def upgrade = { ->
	def success = true
	invoke(SHELL_LINUX, "lib_install_server.sh")
	success = args.JOB_RESULT.toBoolean()
	return success
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

// entry point
def main = { ->
	def getSlave = false
	try {
		def branch901pl13 = "901PL13"
		def branch91pl00 = "91PL00"
		args.NO_CLIENT = true
		args.STRAIGHT = true
		args.BASE_BUILD = args.BASE_BRANCH_BUILD
		if ( args.BASE_BRANCH_BUILD != branch901pl13 && args.BASE_BRANCH_BUILD != branch91pl00 ){
			args.BASE_BRANCH_BUILD = branch91pl00
			args.STRAIGHT = false
		} 
		args.PROC_NAME = "${env.JOB_NAME}"
		args.SLAVE_ACTION = "O"
		invoke(SHELL_LINUX, "lib_slave_pool.sh", "master")
		getSlave = args.JOB_RESULT.toBoolean()
		if (!getSlave) {
			out.println "==== No available slave ====" 
			build.result = hudson.model.Result.ABORTED
			return
		} 
		
		// reset params for upgrade case
		args.TEST_COMP_DB = "SBODEMOUS"
		args.BUILDS_POOL = "${env.UPGRADER_POOL}"
		args.COMPANY_ACTION = "upgrade"
		
		invoke(SHELL_LINUX, "lib_check_upgrade.sh")
		assert args.HAS_NEW_BUILD != null
		assert args.NEW_BUILD_PATH != null
		assert args.PREV_BUILD_PATH != null
		if (!args.HAS_NEW_BUILD.toBoolean()) {
			out.println "==== there is no new build ====" 
			build.result = hudson.model.Result.ABORTED
			return
		} else {
			// a new build is now available
			out.println "==== a new build is now available ====" 
			out.println "NEW build: ${args.NEW_BUILD_PATH}" 
		
			// preinstall the base build
			out.println "Installing the base build: ${args.BASE_BRANCH_BUILD}"
			args.BUILD_PATH = "${env.TOOLS_HOME}/releases/${args.BASE_BRANCH_BUILD}"
			args.CASE_PROP = "${env.TOOLS_HOME}/artifacts/scripts/${args.BASE_BRANCH_BUILD}.properties"
			def success = preInstall()
			assert success
			out.println "Install build ${args.NEW_BUILD_PATH} successfully"

			if(!args.STRAIGHT){
				out.println "Upgrading to ${args.BASE_BUILD}..."
				args.BASE_BRANCH_BUILD = args.BASE_BUILD
				args.BUILD_PATH = "${env.TOOLS_HOME}/releases/${args.BASE_BRANCH_BUILD}"
				args.CASE_PROP = "${env.TOOLS_HOME}/artifacts/scripts/${args.BASE_BRANCH_BUILD}.properties"
				// upgrade from base build
				success = upgrade()
				assert success
				if (success) {
					invoke(SHELL_WIN32, "lib_create_company.bat", args.SLAVE_WIN32)
					success &= args.JOB_RESULT.toBoolean()
				}
				assert success
				out.println "Upgrade to ${args.BASE_BUILD} successfully..."
			}
		
			// intialize the base build
			out.println "Initializing the base build: ${args.BASE_BRANCH_BUILD}"
			args.JMX_CASE_FILE = "${env.TOOLS_HOME}/artifacts/scripts/${args.BASE_BRANCH_BUILD}_Initialize.jmx"
			args.EXIT_WITH_FAILED = true
			invoke(SHELL_LINUX, "lib_run_jmeter.sh", "master")	
			success = args.JOB_RESULT.toBoolean()
			if(!success){
				out.println "Initialization failed for base build"
			}
			assert success
		
			
			out.println "Upgrading to the latest build"
			args.BUILD_PATH = "${env.UPGRADER_POOL}/${args.BRANCH}/new"
			args.CASE_PROP = "${env.TOOLS_HOME}/artifacts/scripts/upgrade.properties"
			args.FULL_BUILD_PATH = args.NEW_BUILD_PATH
			// upgrade from base build
			success = upgrade()
			assert success
		
			if (success) {
				invoke(SHELL_WIN32, "lib_create_company.bat", args.SLAVE_WIN32)
				success &= args.JOB_RESULT.toBoolean()
			}
			assert success
		
			if (success) {
				out.println "==== upgrade build & DBs successfully ====" 
				// archive the build
				args.ARCHIVE_RESULT = true
				invoke(SHELL_LINUX, "lib_archive_build.sh")
			}
		}
		
		
		
		// reboot HDB instance
		invoke(SHELL_LINUX, "lib_reboot_hana.sh")
		
		syncJmx()
		
		// force restart obs before running jmeter
		args.B1S_CONF_REPLACEMENT = true
		invoke(SHELL_LINUX, "lib_restart_sl.sh")
		//invoke(SHELL_WIN32, "lib_restart_obs.bat", args.SLAVE_WIN32)
		// run b1ah and xapp jmx
		args.JMX_CASE_FILE = ""
		args.EXIT_WITH_FAILED = false
		runjmx "SC_B1AH_Upgrade", "SC_XApp_Sanity"
		
		saveEnv()
		
		// display each job invocation elapsed
		showTimeline()	
		
		
		// emit final build result according to test result
		if (args.TEST_STATE == "unstable") {
			out.println "JMeter test case failed, mark build to 'unstable'"
			build.result = hudson.model.Result.UNSTABLE
		}
	} finally {
		if(getSlave){
			args.SLAVE_ACTION = "R"
			invoke(SHELL_LINUX, "lib_slave_pool.sh", "master")
		}
	}
}

// call main
main()
