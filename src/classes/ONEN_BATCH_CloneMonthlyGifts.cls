global virtual class ONEN_BATCH_CloneMonthlyGifts implements Database.Batchable<Sobject>, Database.Stateful {
// Written by Matthew Scholtz and Dave Manelski, copyright (c) 2009 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	global String Query;
	global final String Entity;
	global final String Field;
	global final String Value;
	
	string YearSelection;
	integer YearSelected;

	integer OppCreationCounter=0;

	global ONEN_BATCH_CloneMonthlyGifts (string yearPreseleted){
		YearSelection = yearPreseleted;
		constructQuery();
	}

	global ONEN_BATCH_CloneMonthlyGifts (){
		// alternate no-arg constructor, for use in scheduled circumstances, etc.
		constructQuery();
	}
	
	protected virtual void constructQuery() {
		// grab all opps marked as Monthly Gift, using dynamic SOQL to include all custom fields
		
		// default the year selection based on current month and custom setting
		// but only if it wasn't passed in to the constructor (via VF pg)
		MonthlyGiftsSettings__c settings = MonthlyGiftsSettings__c.getOrgDefaults();
		if (YearSelection==null) {
			if (system.today().month() <= settings.Months_Default_to_Last_Year__c) {
	        	YearSelection = 'LAST_YEAR';
	        } else {
	        	YearSelection = 'THIS_YEAR';
	        }
		}
		if (YearSelection=='THIS_YEAR') 		{	YearSelected = System.Today().Year();}
		else if (YearSelection=='LAST_YEAR') 	{	YearSelected = System.Today().Year() - 1;}
		system.debug ('year selection: ' + YearSelection);
		
        Map<String, Schema.SObjectField> M = Schema.SObjectType.Opportunity.fields.getMap();
        system.debug ('opp schema map: ' + M);
        string querySOQL = 'SELECT ';
        
        //exclude fields that we do not wish to deep clone
        if (settings.FieldsToSkip__c != null) {
	        for (string fieldname : M.keyset()) {
	        	// if (!ONEN_Constants.OPP_CLONE_SKIP_FIELDS.contains(fieldname)) {
	        	if (!settings.FieldsToSkip__c.contains(fieldname)) {
	        		querySOQL += fieldname + ', ';
	        	}
	        }
        } else {
        	for (string fieldname : M.keyset()) {
	        	querySOQL += fieldname + ', ';
	        }
        }

        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM Opportunity WHERE Monthly_Gift__c = true AND IsWon=true AND Monthly_Gift_Discontinued_Date__c = null';
        querySOQL += ' AND Monthly_Gift_Amount__c != null';
        querySOQL += ' AND CloseDate=' + YearSelection;
        system.debug ('query string: ' + querySOQL);
		
		Query = querySOQL;
	}	
	
	global Database.QueryLocator start(Database.BatchableContext BC){
		return Database.getQueryLocator(Query);
	}
	
	global void execute(Database.BatchableContext BC, List<Sobject> OppBatch){
		doCloneOpps(OppBatch);
	}
	

	virtual void doCloneOpps(list<Sobject> SBatch) {
		
		Map<id, id> oldOppToClonedOpp = new Map<id, id>();
		Map<id, id> oppToPrimaryCR = new Map<id, id>();
		Map<id, Opportunity> OldIDToOpp = new Map<id, Opportunity>();

		Opportunity[] OppBatch = new Opportunity[0];
		list<Id> OppIDs = new list<Id>(); 

		// cast sobjects to Opps		
		for (sobject s: SBatch) {
			Opportunity opp = (Opportunity)s;
			OppIDs.add(opp.Id);
			OppBatch.add(opp);
		}
		
		// collect primary contact ID's from opps
		OpportunityContactRole[] ConRoles= [select OpportunityId, ContactId FROM OpportunityContactRole WHERE IsPrimary=true AND OpportunityId IN :OppIDs];
		system.debug ('conroles to insert: ' + ConRoles);
		for (OpportunityContactRole CR : ConRoles) {
			oppToPrimaryCR.put(CR.OpportunityId,CR.ContactId);
		}
		
		// do the clone!!! (only clones in memory)
		list<Opportunity> clonedOpps = OppBatch.deepClone(false);

		// now modify cloned opps before inserting
		for (integer i=0;i<clonedOpps.size();i++) {
			id oldOppID = OppBatch[i].Id;
			
			// trigger contact roles
			if (clonedOpps[i].AccountId == null){
				clonedOpps[i].CR_Contact_Id__c = oppToPrimaryCR.get(oldOppID);
				clonedOpps[i].CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT));
				clonedOpps[i].CR_HHRoles__c = True;
			}
			
			// set up amount based on monthly amt, and date as Jan 1 of new yr
			clonedOpps[i].Amount = OppBatch[i].Monthly_Gift_Amount__c * 12;
			clonedOpps[i].CloseDate = Date.NewInstance(OppBatch[i].CloseDate.Year()+1,1,1); 
			
			// increment year in name, if any (& need to remove commas that SF will stick into the string values for 4-digit nums)
			string txtYear = YearSelected.format().replace(',','');
			integer newYear = YearSelected+1;
			string txtNewYear = newYear.format().replace(',','');
			if (OppBatch[i].Name.contains(txtYear)) {
				clonedOpps[i].Name = OppBatch[i].Name.replace(txtYear,txtNewYear);
			}
			
			// increment member dates, if any, and member origin field
			/* uncomment this section if you're using membership fields
			if (OppBatch[i].Membership_End_Date__c != null) {
				clonedOpps[i].Membership_End_Date__c = OppBatch[i].Membership_End_Date__c.addYears(1);
			}
			if (OppBatch[i].Membership_Start_Date__c != null) {
				clonedOpps[i].Membership_Start_Date__c = OppBatch[i].Membership_Start_Date__c.addYears(1);
			}
			if (OppBatch[i].Membership_Origin__c=='New' || OppBatch[i].Membership_Origin__c=='Reacquire') {
				clonedOpps[i].Membership_Origin__c = 'Renewal';
			}
			*/
						
			OldIDToOpp.put (oldOppId,OppBatch[i]);
		}

		// insert them!!
		system.debug ('opps to insert: ' + clonedOpps);
		insert clonedOpps;
		OppCreationCounter = OppCreationCounter + clonedOpps.size();
		system.debug ('inserted opps: ' + clonedOpps + ' counter: ' + OppCreationCounter);
		
		// make map of each orig opp ID to the ID of its clone
		for (integer i=0;i<clonedOpps.size();i++) {
			oldOppToClonedOpp.put(OppBatch[i].Id,clonedOpps[i].Id);
		}
		system.debug('opp id map: ' + oldOppToClonedOpp);
		
		//now clone the installment payments
		cloneInstallments (clonedOpps);
		
		//delete extra mirror payments from opps with installments
		List<OppPayment__c> mirrorOppPaymentsToDelete = new List<OppPayment__c>();  
        mirrorOppPaymentsToDelete = [Select Id from OppPayment__c where IsInstallment__c=false AND Opportunity__c IN :oldOppToClonedOpp.values()];
        if(mirrorOppPaymentsToDelete.size()>0){
        	delete mirrorOppPaymentsToDelete;
        }
	}


	virtual void cloneInstallments (Opportunity[] clonedOpps) {
		List<OppPayment__c> InstallmentsToCreate = new List<OppPayment__c>();
		
		// figure out which day of month installments should be
		// use setting if set, otherwise default to 1
		integer installmentDay = 1;
		MonthlyGiftsSettings__c settings = MonthlyGiftsSettings__c.getOrgDefaults();
		if (settings.Clone_Installment_Day__c != null ) {
			installmentDay = settings.Clone_Installment_Day__c.intvalue();
		}
		
		for (Opportunity clonedOpp : clonedOpps) {
			for (integer i=1;i<13;i++) {			
				OppPayment__c NewInstall = new OppPayment__c (
					Opportunity__c = clonedOpp.Id,
					Opp_For_Installment__c = clonedOpp.Id,
					IsInstallment__c = true,
					Amount__c = clonedOpp.Monthly_Gift_Amount__c,
					// TBD day should draw from constant, not always be 1
					Date__c = Date.newInstance(clonedOpp.CloseDate.Year(),i,installmentDay),
					Paid__c = False
				);
				InstallmentsToCreate.add(newInstall);
			}
		}
				
		if (InstallmentsToCreate.size()>0 ) {
			insert InstallmentsToCreate;
		}		
	}

	
	global void finish(Database.BatchableContext BC){
		system.debug ('counter at finish: ' + OppCreationCounter);
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		
		// grab email addys from settings obj, and parse
		MonthlyGiftsSettings__c settings = MonthlyGiftsSettings__c.getOrgDefaults();
		string emailList = settings.Clone_Complete_Email_Notify__c;
		if (emailList==null) {emailList = 'matthew@onenw.org';}
		string[] emailAddys = emailList.split(';');
		mail.setToAddresses(emailAddys);

		mail.setSenderDisplayName('Salesforce Batch Processing');
		mail.setSubject('Monthly Gift Renewal Complete');
		mail.setPlainTextBody('The monthly gift renewal process in Salesforce has completed.  Please check to ensure that opportunities have been created as expected.' + 
			'\n\n' + OppCreationCounter + ' monthly gift Opportunities were renewed.');
		Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
	}


// *** TESTS **********************************************************************

public static testMethod void test25Opps() {
	
	// TBD this will only work for now if date is April or later
	
	integer howMany = 25;
	Date datClose = System.Today();
	string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
		
	// create & insert contact(s)
	Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
	insert TestCons;
	system.debug ('first conID: ' + TestCons[0].Id);
	
	// create new opps
	Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Closed Won', datClose, 100 , GiftRectype,null);
	insert newOpps;
	
	for (Opportunity opp : newOpps) {
		opp.Monthly_Gift_Amount__c = 10;
		opp.Monthly_Gift__c = true;
		opp.Name = opp.Name + ' ' + System.Today().Year().format().replace(',',''); 
	}
	update newOpps;

	// have to reset this so that the cloned opps get their conroles
	ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
	
	Test.StartTest();
	ONEN_BATCH_CloneMonthlyGifts myba = new ONEN_BATCH_CloneMonthlyGifts('THIS_YEAR');
	ID batchprocessid = Database.executeBatch(myba);
	Test.StopTest();
	
	System.Assert(database.countquery('SELECT count() FROM Opportunity WHERE Monthly_Gift__c=true AND CloseDate=NEXT_YEAR') >= 25);
	System.Assert(database.countquery('SELECT count() FROM OpportunityContactRole WHERE Opportunity.Monthly_Gift__c=true AND Opportunity.CloseDate=NEXT_YEAR AND IsPrimary=True') >= 25);
	
	OpportunityContactRole newOpp1 = [SELECT Id, Opportunity.Id, Opportunity.Name, Opportunity.Amount, Opportunity.CloseDate,
		Opportunity.Monthly_Gift_Amount__c, Opportunity.Total_Paid__c
		FROM OpportunityContactRole 
		WHERE Opportunity.Monthly_Gift__c=true AND Opportunity.CloseDate=NEXT_YEAR AND ContactID =: TestCons[0].Id 
		LIMIT 1];

		
	// make sure that year strings in the opp name have incremented
	string txtNextYear = System.Today().addYears(1).Year().format().replace(',','');
	system.debug ('newoppname: ' + newOpp1.Opportunity.Name );  
	System.Assert (newOpp1.Opportunity.Name.contains(txtNextYear) );
	
	
}


}