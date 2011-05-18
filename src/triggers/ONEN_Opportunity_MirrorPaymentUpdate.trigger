trigger ONEN_Opportunity_MirrorPaymentUpdate on Opportunity (after update) {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	// if an opp has no installments (meaning it only has a single "mirror" payment
	// we want to update that mirror whenever the Opp chgs date / Amt / Stage
	// this is done by updating a field that triggers a workflow rule + field update
	
	system.debug ('TRIGGER FIRED');

	set<id> OppsToUpdate = new set<id>();
	map<id,Opportunity> oppUpdateMap = new map<id,Opportunity>();
	
	for ( Opportunity thisOpp : trigger.new ) {
		
		Opportunity oldOpp = trigger.oldMap.get(thisOpp.id);
		
		// see if any of the relevant fields have changed
		if ( 	thisOpp.Amount != oldOpp.Amount ||
				thisOpp.StageName != oldOpp.StageName ||
				thisOpp.CloseDate != oldOpp.CloseDate ||
				thisOpp.Check_Number__c != oldOpp.Check_Number__c ||
				thisOpp.Check_Date__c != oldOpp.Check_Date__c
		) {
			// if so, add to set for processing	
			oppUpdateMap.put(thisOpp.id, thisOpp);
		}	
		
		if (!oppUpdateMap.isEmpty()) ONEN_OpportunityInstallments.updateMirrorPayments(oppUpdateMap);
	}
		
}