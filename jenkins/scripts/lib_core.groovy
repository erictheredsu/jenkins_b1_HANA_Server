
// convert params to Groovy map
def args = [:] << params

// timing logs
def jobs = []

// constant job names
def SHELL_LINUX = "SHELL_LINUX"
def SHELL_WIN32 = "SHELL_WIN32"
def SYNC_SOURCE = "SYNC_SOURCE"
def SYNC_JMX	= "SYNC_JMX"

// job parameters
def env 				= build.properties.environment
def WORKSPACE 			= env.WORKSPACE
def BUILD_NUMBER 		= env.BUILD_NUMBER
def JENKINS_HOME 		= env.JENKINS_HOME
def BUILDS_POOL 		= env.BUILDS_POOL
def CURRENT_SPACE		= new File("${WORKSPACE}/${BUILD_NUMBER}")
args.SLAVE_LINUX		= args.HDB_HOST
args.BUILD_ZIP_FILE		= "\\\\${args.HDB_HOST}\\b1_shf\\Client.zip"
args.UPGRADER_ZIP_FILE		= "\\\\${args.HDB_HOST}\\b1_shf\\Wizard"
def BUILD_MARK			= env.BUILDS_POOL /*env.MNT_PATH*/

// extract output parameters
def extract = { String log, String newLine ->
	def map = [:]
    def lines = log.split(newLine)
    def matchList = {
        def matcher = ( it =~ /.*^!![A-Z_0-9]*=.*/ )
        if (matcher.matches()) {
            for (m in matcher) {
                def a = m.split("=", 2)
                map.put (a[0].substring(2), a[1])
            }
        }
    }
    lines.each(matchList)
    return map
}

// shell execute command
def shell = { cmd ->
	out.println "shell execute command -> $cmd"
	def proc = cmd.execute()
	out.println "return -> " + proc.text
	proc.waitFor()
	return proc.exitValue()
}

// save args to workspace for future usage (e.g. send mail)
def saveEnv = { ->
	new File("args.properties", CURRENT_SPACE).withWriter{ fs ->
		args.each { fs.println it.toString().replace("\\", "\\\\") }
	}
}

// invoke job, extract output parameters and inject into 'args'
def invoke = { String job, String script, String node = args.SLAVE_LINUX ->

	// begin of job
	def timeStart = new Date()

	out.println ""
	out.println "======= Begin of ${job} -> ${script} @${node} ======="
	// change node and script dynamically
	args.JOB_EXECUTOR = node
	args.JOB_SCRIPT = script

	// save the env in case the workflow fails by unhandled exception
	if ( script != "lib_slave_pool.sh" ){
		saveEnv()
	}
	
	// invoke job, ignore the UNSTABLE state of the last build.
	def rs
	ignore(hudson.model.Result.UNSTABLE){
    	rs = build(args, job)
    }
    out.println rs.log
	out.println "======= End of ${job} -> ${script} @${node} =======" 

	// check result
	assert rs.result.name != "FAILURE"

	// extract output parameters
	def map = extract(rs.log, (job == SHELL_LINUX ? "\n" : "\r\n") )
	for(cc in map) {
		out.println "returns ${cc}"
	}
	args << map	
	out.println ""

	// end of job
	def timeStop = new Date()
 	def elapsed = groovy.time.TimeCategory.minus(timeStop, timeStart)
 	jobs << "job ${job} - ${script} @${node} took ${elapsed}"

	return rs	
}

// display each job invocation elapsed
def showTimeline = { ->
	out.println ""
	out.println "Workflow completed, now display job status;"
	jobs.each { out.println it }
	out.println ""
}

// setBuildState
def setBuildState = { branch, pkg, state, clue ->
	def dir = new File("${BUILD_MARK}${branch}/${pkg}")
	if (!dir.exists()) {
		dir.mkdirs()
	}
	def hr = new File(state, dir)
	hr.write(clue)
	return hr
}

// getBuildState
def getBuildState = { branch, pkg, state ->
	def dir = new File("${BUILD_MARK}${branch}/${pkg}")
	if (!dir.exists()) {
		dir.mkdirs()
	}
	return new File(state, dir).exists()
}

// isBuildRunning
def isBuildRunning = { branch, pkg ->
	return getBuildState(branch, pkg, "InstallationRunning.txt")
}

// isBuildPassed
def isBuildPassed = { branch, pkg ->
	return getBuildState(branch, pkg, "InstallationPassed.txt")
}

// isBuildFailed
def isBuildFailed = { branch, pkg ->
	return getBuildState(branch, pkg, "InstallationFailed.txt")
}

// setBuildRunning
def setBuildRunning = { branch, pkg, clue ->
	return setBuildState(branch, pkg, "InstallationRunning.txt", clue)
}

// unmarkBuildRunning
def unmarkBuildRunning = { branch, pkg ->
	new File("${BUILD_MARK}${branch}/${pkg}/InstallationRunning.txt").delete()
}

// setBuildPassed
def setBuildPassed = { branch, pkg, clue ->
	return setBuildState (branch, pkg, "InstallationPassed.txt", clue)
}

// setBuildFailed
def setBuildFailed = { branch, pkg, clue ->
	return setBuildState (branch, pkg, "InstallationFailed.txt", clue)
}

// validate build
def validateBuild = { branch, pkg ->
	assert !isBuildFailed (branch, pkg)
}

// check build
def checkBuild = { branch, ignoreFailure = false ->

    // check available build
    out.println "Checking ${branch} codeline..."
    
    def rc = []
    if ( !new File("${env.MNT_PATH}${branch}").exists() ) {
    	out.println "Mount the builds shared folder ${env.BUILDS_SHARE_FOLDER}"
    	shell("mount.cifs -o username=${env.BUILDS_SHARE_FOLDER_USER},password=${env.BUILDS_SHARE_FOLDER_PWD} ${env.BUILDS_SHARE_FOLDER} ${env.MNT_PATH}")
    }
    new File("${env.MNT_PATH}${branch}").eachDirMatch(~/.*HANA/) { dir ->
        rc << dir
    }
     
    def top = rc.sort() { a, b ->
        def x = (a.name.split('_').last() - ".HANA").toInteger()
        def y = (b.name.split('_').last() - ".HANA").toInteger()

        def r = y <=> x
        if (r == 0) {
            r = b.lastModified() <=> a.lastModified()
        }
        return r
    }.dropWhile { dir ->
    	def unexsits = !new File("build_copy_done.txt", dir).exists()
    	if (unexsits) {
    		return true
    	}

    	if (!ignoreFailure) {
    		return isBuildFailed(branch, dir.name)
    	}

    	return false
    }.first()
    
    out.println "The latest build of ${branch} is ${top.name}"

    return top.name	
}

// standardize the parameters e.g. trim the leading and trailing spaces
def polishArgs = { ->
	args.HDB_HOST = args.HDB_HOST.trim()
	args.HDB_INST = args.HDB_INST.trim()
	args.HDB_USR = args.HDB_USR.trim()
	args.BUILD_PKG = args.BUILD_PKG ? args.BUILD_PKG.trim() : ""
}

def preinit = { -> 
	
	// create workspace with build number
	CURRENT_SPACE.mkdir()
	
	// save the env in case the workflow fails by unhandled exception
	saveEnv()
	
	polishArgs()
}

def analyzeResponsibility = { jmeter,ut,jmeter_htmls ->
	out.println("Start analyzing responsibility")
	
	def recipients = new StringBuffer()
	
	//Load table
	out.println("Load table")
	def recipients_table = new java.util.Properties()
	recipients_table.load(new FileInputStream("/home/jenkins/tools/artifacts/scripts/responsible_table.properties"))
	

	//For jmeter
	out.println("For jmeter")
	if (jmeter) {
		jmeter_htmls.each {
			//Load html, get rid of body size limatation, select failure elements
			def doc = org.jsoup.Jsoup.connect("${env.JENKINS_URL}job/${env.JOB_NAME}/ws/${jmeter}/${it}.html").maxBodySize(0).get()
			def elements = doc.select("tr[valign].Failure>td:first-child")
			for (def i = 0; i < elements.size(); i++) {
				//Get the group str
				def str = elements.get(i).text()
				
				if (str.startsWith("DS_")) {
					def index = str.indexOf("_",3);
					if (index>0) {
						str = str.substring(0,str.indexOf("_", 3));					
					}else {
						str = str.replaceAll(" - .*", "");				
					}
				}else {
					str = str.replaceAll("_.*", "");				
				}

				//Look for the table, Add to recipients
				def addr = recipients_table.get(str)
				

				if (addr!=null &&!addr.isEmpty()&&!recipients.contains(addr)) {
					recipients << addr << ";"
					out.println("${str} -> ${addr}")
				}
			}
		}
	}

	//For UT
	out.println("For UT")
	if (ut) {	
		def _docUT = org.jsoup.Jsoup.connect("${env.JENKINS_URL}job/UnitTest_Coverage/${ut}/testReport/").get()
		def elements = _docUT.select("table.pane.sortable.bigtable:not(#testresult) a.model-link.inside:not(a[href^=/])");
		for (def i = 0; i < elements.size(); i++) {
			def str = elements.get(i).text();
			def last = str.lastIndexOf(".");
			def secondLast = str.substring(0, last).lastIndexOf(".");
			str = str.substring(0,secondLast);

			//Look for the table, Add to recipients
			def addr = recipients_table.get(str);
			
			if (addr!=null &&!addr.isEmpty()&&!recipients.contains(addr)) {
				recipients << addr << ";"
				out.println("${str} -> ${addr}")
			}
		}
	}


	//Write to file for future reading
	new File("/tmp/recipients_${env.JOB_NAME}").text = recipients;


	out.println("End analyzing responsibility")
	out.println(recipients);
}

preinit()