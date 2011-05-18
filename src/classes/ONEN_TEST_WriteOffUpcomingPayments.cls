@isTest
private class ONEN_TEST_WriteOffUpcomingPayments {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    static testMethod void discontinuePayments() {
        
		//create an opportunity
		Opportunity firstOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name='Test Opp',
			StageName = 'Closed Won',
			CloseDate = System.Today(),
			Amount=100			
		);
		
		insert firstOpp;
			
		//now create a bunch of payments
		List<OppPayment__c> paymentsToCreate = new List<OppPayment__c>();
		OppPayment__c p1 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today(),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = True 
		);
		paymentsToCreate.add(p1);
		
		OppPayment__c p2 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today().addDays(10),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = False 
		);
		paymentsToCreate.add(p2);
		
		OppPayment__c p3 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today().addDays(20),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = False 
		);
		paymentsToCreate.add(p3);
		
		OppPayment__c p4 = new OppPayment__c (
			Amount__c = 25,
			Date__c = Date.today().addDays(30),
			IsInstallment__c = True,
			Opportunity__c = firstOpp.id,
			Opp_For_Installment__c = firstOpp.id,
			Paid__c = False 
		);
		paymentsToCreate.add(p4);
		
		if (paymentsToCreate.size()>0) {
			insert paymentsToCreate;
		}
		
		//now update the opp to discontinue payments
		firstOpp.Monthly_Gift_Discontinued_Date__c = Date.today();
		update firstOpp;
		
		//SOQL the results to find out if trigger fired and remaining unpaid payments were set to written off
    	OppPayment__c[] writtenOffPayments = [SELECT Written_Off__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id AND IsInstallment__c = true AND Written_Off__c = true];
    	System.assertEquals(writtenOffPayments.size(),3);
    
    }
}