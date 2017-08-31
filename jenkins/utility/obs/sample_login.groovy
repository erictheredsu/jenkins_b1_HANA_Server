/*!
 *  Login to the current company
 */
import com.sap.businessone.obs.*

company.setDbServerType(BoDataServerTypes.dst_HANADB)
company.setServer("10.58.121.140:30015")
company.setCompanyDB("SBOTESTUS")
company.setDbUserName("SYSTEM")
company.setDbPassword("manager")
company.setUserName("manager")
company.setPassword("manager")
company.setLicenseServer("10.58.121.140:40000")

def rs = company.connect()
if (rs != 0) {
    company.fault()
}

json {
    message "Login successfully"  
}