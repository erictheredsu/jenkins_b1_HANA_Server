/*! 
 *	Observer proxy servlet
 */
import groovy.json.JsonBuilder
import com.sap.businessone.obs.ClassFactory

response.setContentType("application/json")
try {
	if (request.method == "POST") {

		// get or create session
		if (!session) {
			session = request.getSession(true)
		}

		// create or get company instance from session
		def company = session.company
		if (!company) {
			company = ClassFactory.createCompany()
			company.metaClass.fault = {
				throw new RuntimeException("code: ${company.getLastErrorCode()}, message: ${company.getLastErrorDescription()}")
			}
			session.company = company
		}

		def binding = new Binding([json: json, company: company])
		new GroovyShell(binding).evaluate(request.getReader())
	} else {
		json {
			message "DIAPI(x64) on the fly is working..."
		}
	}
} catch (Exception e) {
	json {
		error e.message
		type e.class.name
	}
	response.setStatus(500)
}