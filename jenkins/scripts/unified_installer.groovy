/*!
 *	B1AH Smoke Test Workflow
 */

// entry point
def main = { ->

	def new_pod_build = true
	invoke(SHELL_LINUX, "lib_check_pod_build.sh")

	new_pod_build = args.HAS_NEW_POD_BUILD.toBoolean()
	args.BUILD_PATH = "${env.POD_BUILDS_POOL}/${args.BRANCH}/prev"
	args.FULL_BUILD_PATH = args.PREV_POD_BUILD_PATH

	if(!new_pod_build){
		out.println "There is no new installer package"
		return 0
	}

	invoke(SHELL_LINUX, "lib_check_build.sh")
	// archive
	args.ARCHIVE_RESULT = true
	invoke(SHELL_LINUX, "lib_archive_build.sh")

	// true -> ${BUILD_POOL}/${BRANCH}/new
	// false -> ${BUILD_POOL}/${BRANCH}/prev
	// always send prev path if the code has been archived.
	
	invoke(SHELL_LINUX, "lib_prepare_pod_build.sh")
	// cleanup all (b1 and db)
	invoke(SHELL_LINUX, "lib_cleanup_all.sh")

	// install SLD, SBOCOMMON, XApp and B1AH
	args.INSTALL_TYPE = "ALL"
	invoke(SHELL_LINUX, "lib_install_server.sh")
	assert args.JOB_RESULT.toBoolean()

	// copy result to workspace
	saveEnv()

	// display each job invocation elapsed
	showTimeline()	
}

// call main
main()
