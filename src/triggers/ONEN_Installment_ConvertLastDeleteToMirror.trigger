trigger ONEN_Installment_ConvertLastDeleteToMirror on OppPayment__c (after delete) {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	// if a user tries to delete the last installment on an opp, create a mirror pmt to take its place
	// but only if the opp hasn't also been deleted
	
	// as of now (1/23/08), cascade deletes don't fire apex delete triggers, so this shouldn't be an issue
	// but we'll handle it in an attempt to future-proof this
	
	system.debug ('TRIGGER FIRED');

	set<id> OppsToCheck = new set<id> ();
	list<Opportunity> OppsToMirror = new list<Opportunity> ();
	list<OppPayment__c> OPToCreate = new list<OppPayment__c> ();
	map<id,integer> PmtCountsPerOpp = new map<id,integer>();
	
	for ( OppPayment__c thisPmt : trigger.old ) {
		OppsToCheck.add (thisPmt.Opportunity__c);
	}
	
	system.debug ('TEST>>>> OppsToCheck: ' + OppsToCheck);
	
	Opportunity[] OppsWithPmtsLeft = [SELECT id, Name, Amount, CloseDate, IsWon, Check_Number__c, Check_Date__c, (SELECT id, IsInstallment__c FROM Payments__r) FROM Opportunity WHERE id IN :OppsToCheck ]; 
	
	for ( Opportunity thisOpp : OppsWithPmtsLeft ) {
		system.debug ('TEST>>>> Opp being checked: ' + thisOpp);
		// if ( thisOpp.payments__r == null ) {
		if ( thisOpp.Payments__r.size() == 0 ) {
			OppsToMirror.add (thisOpp);	
		}	
	}
	
	if ( OppsToMirror.size() > 0 ) {
		OPToCreate = ONEN_OpportunityInstallments.GetMirrorPayments (OppsToMirror);	
	}

	system.debug ('Payments to create: ' + OPToCreate.size() );

	if ( OPToCreate.size() > 0 ) {
		insert OPToCreate;
	}			

}