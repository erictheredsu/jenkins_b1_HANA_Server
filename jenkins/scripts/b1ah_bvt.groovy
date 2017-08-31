/*!
 *    B1AH BVT Workflow
 */

// entry point
def main = { ->
    
    /*
    def concurrent = true
    def targets = [
        "dev":      ["10.58.132.246", false, ""],
        "9.1_DEV":  ["10.58.132.167", false, ""],
        "9.1_COR":  ["10.58.132.154", false, ""],
        "9.01_DEV": ["10.58.132.190", false, ""],
        "9.01_COR": ["10.58.132.178", false, ""],
    ]
    */
    
    // only one VM is available due to cost saving
    def concurrent = false
    def targets = [
        "dev":      ["10.58.132.167", false, ""],
        "9.1_DEV":  ["10.58.132.167", false, ""],
        "9.1_COR":  ["10.58.132.167", false, ""],
        "9.01_DEV": ["10.58.132.167", false, ""],
        "9.01_COR": ["10.58.132.167", false, ""],
    ] 

    // check available build
    targets.each {
        def branch = it.key
        def pkg = checkBuild(branch, true)

        if (isBuildPassed(branch, pkg) || isBuildFailed(branch, pkg)) {
            out.println " which has already been tested"
        } else if (isBuildRunning(branch, pkg)) {
			out.println " which is under testing"
		} else {
            out.println " which is going to be tested"
            it.value[1] = true
            it.value[2] = pkg
        }
    }

    // prepare execution closure
    def runner = [:]
    targets.each {
        def key = it.key
        def value = it.value
        def branch = it.key
        def proc = {

            def skip = !value[1]
            def executor = value[0]
            def pkg = value[2]

            if (skip) {
                out.println "skipping bvt test on ${branch}"
                return
            }

            out.println "starting bvt test on ${branch} at ${executor}"
            
            // copy args
            def pp = [:] << args
            pp.BRANCH = branch
            pp.HDB_HOST = executor
            pp.BUILD_PKG = env.BUILDS_SHARE_FOLDER.replace('/', '\\') + "${branch}\\${pkg}"

            setBuildRunning(branch, pkg, "")
            def rs
            for(current in 1..3) {
                rs = build(pp, "INSTALLATION_SERVICE")
                if (rs.result.name == "SUCCESS") {
                    break
                }
                if (rs.log.contains("java.lang.OutOfMemoryError: PermGen space")) {
                    out.println "out of memory [$current], rerun $branch"
                } else {
                    break
                }
            }
            unmarkBuildRunning(branch, pkg)

            // save result
            def marker = (rs.result.name == "SUCCESS" ? setBuildPassed : setBuildFailed)
            def clue = "${env.JENKINS_URL}${rs.build.url}"
            def hr = marker(branch, pkg, clue)
            out.println "save build result to ${hr}"
        }
        runner << ["${branch}": proc]
    }

    // run bvt test
    ignore(hudson.model.Result.FAILURE) {
        if (concurrent) {
            parallel (runner)
        } else {
            runner.each {
                it.value()
            }
        }
    }

}

// call main
main()

