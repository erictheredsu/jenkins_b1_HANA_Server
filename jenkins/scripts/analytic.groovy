/*!
 *	collect all the hisotry data for installation service
 */
import groovy.util.XmlSlurper
import static groovyx.gpars.GParsPool.withPool


def ROOT = "/home/jenkins/.jenkins/jobs/INSTALLATION_SERVICE"
def NEXTBUILDNUMBER = "$ROOT/nextBuildNumber"
def BUILDS = "$ROOT/builds"

def total = new File(NEXTBUILDNUMBER).text.toInteger() - 1
println "total builds -> $total"

def rs = withPool {
	(1..total).toArray().collectParallel {
		def source = new File("$BUILDS/$it/build.xml")
		if (!source.exists()) {
			return []
		}

		def xml = new XmlSlurper().parseText(new File("$BUILDS/$it/build.xml").text)
		def params = xml.actions."hudson.model.ParametersAction".parameters.children()
		//println params
		
		def number = xml.number.text()
		def startTime = new Date(xml.startTime.text().toLong())
		def startDate = startTime.format("MM/dd/yyyy")
		def startTimeZ = startTime.format("HH:mm:ss")
		def result = xml.result.text()
		def duration = xml.duration.text()

		def hdbhost = params.find{ it.name.text() == "HDB_HOST" }.value.text()
		def hdbinst = params.find{ it.name.text() == "HDB_INST" }.value.text()
		def branch = params.find{ it.name.text() == "BRANCH" }.value.text()
		def pkg = params.find{ it.name.text() == "BUILD_PKG" }.value.text()

		def us = params.find{ it.name.text() == "SBOTESTUS" }.value.text().toBoolean()
		def cn = params.find{ it.name.text() == "SBOTESTCN" }.value.text().toBoolean()
		def de = params.find{ it.name.text() == "SBOTESTDE" }.value.text().toBoolean()
		def anycomp = us | cn | de

		def applicant = params.find{ it.name.text() == "APPLICANT_NAME" }.value.text()
		def email = params.find{ it.name.text() == "APPLICANT_EMAIL" }.value.text()

		[number, startDate, startTimeZ, result, duration, hdbhost, hdbinst, branch, pkg, us, cn, de, anycomp, applicant, email]
	}
}

new File("usage.csv").withWriter { fs ->
	fs.println "number,startDate,startTime,result,duration,hdbhost,hdbinst,branch,pkg,us,cn,de,anycomp,applicant,email"
	rs.each {
		def ss = it.toString()
		if (ss != "[]") {
			fs.println ss.substring(1, ss.length() - 1)
		}
	}
}

println "analysis done"