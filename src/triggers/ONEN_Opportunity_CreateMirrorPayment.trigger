trigger ONEN_Opportunity_CreateMirrorPayment on Opportunity (after insert) {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	// every time we add an opp, create a non-installment payment obj that mirrors the opp
	// (contains same amount and date)
	// most field assignment is handled by workflow, all we have to do is create the obj

	// TBD - maybe want list of rectypes that shouldn't trigger this?? (non-financial opps?)


	system.debug ('TRIGGER FIRED');

	//set<id> OppsToMirror = new set<id> ();
	list<Opportunity> OppsToMirror = new list<Opportunity>();
	list<OppPayment__c> OPToCreate = new list<OppPayment__c> ();

	
	for ( Opportunity thisOpp : trigger.new ) {
		//OppsToMirror.add (thisOpp.id);
		OppsToMirror.add (thisOpp);
	}

	if ( OppsToMirror.size() > 0 ) {
		OPToCreate = ONEN_OpportunityInstallments.GetMirrorPayments (OppsToMirror);	
	}

	system.debug ('Payments to create: ' + OPToCreate.size() );

	if ( OPToCreate.size() > 0 ) {
		insert OPToCreate;
	}			

}