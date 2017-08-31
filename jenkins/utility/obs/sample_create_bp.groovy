/*! 
 *	Add a BusinessPartner to the current logon company
 */
import com.sap.businessone.obs.*

def bp = company.getBusinessObject(BoObjectTypes.oBusinessPartners).queryInterface(IBusinessPartners.class)

bp.setCardCode("CCXSS3121")
bp.setCardName("jmeter customer 1122")

def rs = bp.add()
if (rs != 0) {
    company.fault()
}

json {
	BackOrder bp.getBackOrder()
	CommissionGroupCode bp.getCommissionGroupCode()
}