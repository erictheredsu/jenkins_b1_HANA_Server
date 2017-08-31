/*!
 *	B1AH Smoke Test Workflow
 */

def runjmx = { testName -> 
	args.JMX_FILE = "${testName}.jmx"
	args.TEST_NAME = testName
	invoke(SHELL_LINUX, "lib_run_jmeter.sh", "master")	

	// copy result to workspace
	shell("cp ${args.TEST_RESULT} ${CURRENT_SPACE}/")
	shell("cp ${args.TEST_HTML} ${CURRENT_SPACE}/")
}

// entry point
def main = { ->

	// fetch the latest/specific build
	// returns
	//	HAS_NEW_BUILD -> true/false
	invoke(SHELL_LINUX, "lib_check_build.sh")

	// archive
	args.ARCHIVE_RESULT = true
	invoke(SHELL_LINUX, "lib_archive_build.sh")

	// true -> ${BUILD_POOL}/${BRANCH}/new
	// false -> ${BUILD_POOL}/${BRANCH}/prev
	// always send prev path if the code has been archived.
	args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/prev"
	args.FULL_BUILD_PATH = args.PREV_BUILD_PATH
	
	// cleanup all (b1 and db)
	invoke(SHELL_LINUX, "lib_cleanup_all.sh")

	// install SLD, SBOCOMMON, XApp and B1AH
	args.INSTALL_TYPE = "ALL"
	invoke(SHELL_LINUX, "lib_install_server.sh")
	assert args.JOB_RESULT.toBoolean()

	// create company
	invoke(SHELL_WIN32, "lib_create_company.bat", args.SLAVE_WIN32)
	assert args.JOB_RESULT.toBoolean()

	// deploy obs cloud
	invoke(SHELL_WIN32, "lib_deploy_obs.bat", args.SLAVE_WIN32)
	assert args.JOB_RESULT.toBoolean()

	// run jmeter with smoke tests
	runjmx "B1AH_sanity"

	// copy result to workspace
	saveEnv()

	// display each job invocation elapsed
	showTimeline()	
}

// call main
main()
