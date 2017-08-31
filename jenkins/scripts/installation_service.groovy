/*!
 *	Installation Service Workflow
 */


def redirect = { ->
	out.println("##################redirecting")
	def share_folder = args.BUILD_PKG
	def mnt_path = env.MNT_PATH + args.BRANCH

	if(share_folder){


		//replace '\' to '/', remove last '\''
		share_folder = share_folder.replaceAll(/\$/,"")
		share_folder = share_folder.replace("\\","/")
		out.println("${share_folder}")
		if(!share_folder.matches("^//.*/.*")){
			out.println("BUILD_PKG not matches the format")
			assert false
		}
		//HERE share_folder will be like //xx.xx.xx.xx/aaa or //xx.xx.xx.xx/aaa/
		//Make aaa as PKG, the rest as share_folder
		//user specific
		args.BUILD_PKG = share_folder.substring(share_folder.lastIndexOf("/")+1)
		share_folder = share_folder.substring(0,share_folder.lastIndexOf("/"))
	}else{
		//trational way
		//MAKE share_folder like //10.58.xx.xx/xxx/dev
		args.BUILD_PKG = checkBuild(args.BRANCH)
		share_folder = env.BUILDS_SHARE_FOLDER + args.BRANCH

	}
	args.FULL_BUILD_PATH = (share_folder+"/"+args.BUILD_PKG).replace("/","\\")


	out.println("Prepare to mount "+ share_folder)
	out.println("PKG: "+args.BUILD_PKG)


	def mount_script = "mount.cifs -o username=${env.BUILDS_SHARE_FOLDER_USER49},password=${env.BUILDS_SHARE_FOLDER_PWD49} ${share_folder} ${mnt_path}"



	out.println("mnt_path: " + mnt_path)
	out.println("Script: "+mount_script)

	args.MOUNT_SCRIPT = mount_script
}

// entry point
def main = { ->

	// check build
	redirect()

	// precheck if the input args are valid or not
	invoke(SHELL_LINUX, "lib_precheck.sh", "master")

	// create linux slave
	invoke(SHELL_LINUX, "lib_create_slave.sh", "master")
	
	// install essential packages on linux slave, e.g. hdb client, libstdc...
	invoke(SHELL_LINUX, "lib_prepare_slave.sh")
		
	// fetch the latest/specific build
	invoke(SHELL_LINUX, "lib_check_build.sh")

	// archive
	args.BUILD_PATH = "${BUILDS_POOL}/${args.BRANCH}/new"
	
	// cleanup all (b1 and db)
	invoke(SHELL_LINUX, "lib_cleanup_light.sh")

	// install SLD, SBOCOMMON, XApp and B1AH
	//args.INSTALL_TYPE = "ALL"
	args.INSTALL_TYPE = "BASE"
	invoke(SHELL_LINUX, "lib_install_server.sh")
	assert args.JOB_RESULT.toBoolean()

	// reboot HDB instance
	invoke(SHELL_LINUX, "lib_reboot_hana.sh")

	// create company
	if ( args.SBOTESTUS == "true" || args.SBOTESTCN == "true" || args.SBOTESTDE == "true" ){
		invoke(SHELL_WIN32, "lib_create_company.bat", args.SLAVE_WIN32)
		assert args.JOB_RESULT.toBoolean()
	}
	else {
		out.println("skip creating company dbs...")
	}
	
	// copy result to workspace
	saveEnv()

	// display each job invocation elapsed
	showTimeline()
}

// call main
main()
