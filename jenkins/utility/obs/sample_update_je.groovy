/*!
 *	Update JournalEntry 1754
 */
import com.sap.businessone.obs.*

IJournalEntries je = company.getBusinessObject(BoObjectTypes.oJournalEntries).queryInterface(IJournalEntries.class)

je.getByKey(1754)
je.setProjectCode("PRJ01")

def rs = je.update()
if (rs != 0) {
    company.fault()
}

json {
	BlanketAgreementNumber je.getBlanketAgreementNumber()
	AutomaticWT je.getAutomaticWT()
}