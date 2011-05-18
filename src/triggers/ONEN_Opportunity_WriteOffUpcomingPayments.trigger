trigger ONEN_Opportunity_WriteOffUpcomingPayments on Opportunity (after update) {
// Written by Dave Manelski, copyright (c) 2009 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	// if an opp is a monthly payment and is marked as discontinued,
	// we want to update the upcoming unpaid installment payments to Written Off
	// trigger written for a single update only, does not work in bulk
 
	if (trigger.size==1 && trigger.new[0].Monthly_Gift_Discontinued_Date__c != null && trigger.old[0].Monthly_Gift_Discontinued_Date__c == null) {

		// get the installment payments for this opp
		OppPayment__c[] OppPayments = [SELECT id, Written_Off__c FROM OppPayment__c WHERE IsInstallment__c = true AND Paid__c = false AND Opportunity__c = :trigger.new[0].id];
   
		if ( OppPayments.size() > 0 ) {
  
			// for the mirror payments we found, set the written off flag
			for ( OppPayment__c thisPaymt : OppPayments ) {
				thisPaymt.Written_Off__c = true;
			}
  
			update OppPayments;
		}
	}
}