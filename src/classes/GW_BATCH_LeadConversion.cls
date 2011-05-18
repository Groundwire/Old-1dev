global class GW_BATCH_LeadConversion implements Database.Batchable<SObject> {
// batch apex class to convert matched leads and all new contacts
// Written by Dave Manelski, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public String query { get; set; }

	// constructors
	public GW_BATCH_LeadConversion(string q) { 
		query = q; 
	}

	global database.Querylocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);		 
	}
	
	//get individual account id
	Id IndividualAccountId = ONEN_DefaultAccount.getIndividualAccountId();
	//individual account name
	String IndividualAccountName = ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;
	//set the org name not provided default label
	String NotProvidedLabel = ONEN_Constants.NOT_PROVIDED_LABEL;

	global public void execute(Database.BatchableContext bc, Sobject[] results) {
		
		// run rollups for this batch		
		ONEN_LeadConversion lc = new ONEN_LeadConversion(20);
		lc.leads = new List<Lead>();
		for (sObject s : results) {
			lc.leads.add((lead)s);
		}
		system.debug(lc.leads + 'LEADS TO CONVERT');
 		
 		lc.MatchLeads();
 		system.debug(lc.matchmap + 'LEAD MATCHMAP');
 		// set up the list of leads to convert
		ONEN_LeadConversion.convertSpec[] cs = new ONEN_LeadConversion.convertSpec[0];
		
		//create a dupes list so we don't merge to the same contact more than once
		List<ONEN_LeadConversion.leadMatchup> dupes = new list<ONEN_LeadConversion.leadMatchup>();
 		Set<id> cmatches = new Set<id>();
 		
 		for (Id l : lc.matchMap.keyset()) {	
						
			ONEN_LeadConversion.LeadMatchup lm = lc.matchMap.get(l);
			system.debug('Value of LM ' + lm);
			system.debug('Contact Matches ' + lm.cons);
			if ((lm.cons == null || (lm.conMatchMap.get(lm.cons[0].id) != 'last' && (lm.cons.size() == 1 || lm.conMatchMap.get(lm.cons[1].id)  == 'last'))) && 
				(lm.accts == null || lm.accts.size() < 2) &&
				(lm.opps == null || lm.opps.size() < 2)) {
				
				//create a map to test whether or not duplicate contacts are being
				//added to the map, since we can't perform the ContactFix updates
				//to a list of contacts that contains dupes. 
				if ( lm.cons == null || !cmatches.contains(lm.cons[0].id)) {
					ONEN_LeadConversion.ConvertSpec cs1 = new ONEN_LeadConversion.ConvertSpec();
					cs1.leadId = lm.theLead.id;
					cs1.contactId = lm.cons == null ? null : lm.cons[0].id;
					cs1.accountId = (lm.accts == null || lm.theLead.Company==null || lm.theLead.company=='' || lm.theLead.company==NotProvidedLabel || lm.theLead.company==IndividualAccountName) ? IndividualAccountId : lm.accts[0].id;
					cs1.oppId = lm.opps == null ? null : lm.opps[0].id;
					cs.add(cs1);
					if (lm.cons != null) cmatches.add(lm.cons[0].id);
				} else {
					dupes.add(lm);
				}	
				
			}
			
		}
		//system.debug('Conversion Specs ' + cs);
		//system.debug('Dupes Collection ' + dupes);
		
		lc.convertLeads(cs);			 
		
		
		// continue looping through leads matching to duplicate contacts and convert them, one at a time if necessary
		// this may hit governor limits if there are many many leads matching to the same contact
		while (dupes.size() > 0) {
			system.debug('While loop runnning... ');
			lc.leads = new List<Lead>();
			for (ONEN_LeadConversion.LeadMatchup lm : dupes) {
				lc.leads.add(lm.theLead);
			}
			
			lc.MatchLeads();
			
			cs = new ONEN_LeadConversion.convertSpec[0];
			
			cmatches = new Set<id>();
			List<ONEN_LeadConversion.LeadMatchup> additionalDupes = new List<ONEN_LeadConversion.LeadMatchup>();
			
			for (ONEN_LeadConversion.LeadMatchup lm : dupes) {
				//create a map to test whether or not duplicate contacts are being
				//added to the map, since we can't perform the ContactFix updates
				//to a list of contacts that contains dupes. 
				if (lm.cons == null || !cmatches.contains(lm.cons[0].id)) {
					ONEN_LeadConversion.ConvertSpec cs1 = new ONEN_LeadConversion.ConvertSpec();
					cs1.leadId = lm.theLead.id;
					cs1.contactId = lm.cons == null ? null : lm.cons[0].id;
					cs1.accountId = (lm.accts == null || lm.theLead.Company==null || lm.theLead.company=='' || lm.theLead.company==NotProvidedLabel || lm.theLead.company==IndividualAccountName) ? IndividualAccountId : lm.accts[0].id;
					cs1.oppId = lm.opps == null ? null : lm.opps[0].id;
					cs.add(cs1);
					if (lm.cons != null) cmatches.add(lm.cons[0].id);
				} else {
					additionalDupes.add(lm);
				}
			}
			
			
			lc.convertLeads(cs);			 
			
			//continue to loop through dupes until all have been converted
			dupes =  new List<ONEN_LeadConversion.LeadMatchup>();
			dupes.addAll(additionalDupes);
			
		}
 
	}

	global void finish(Database.BatchableContext bc) {
	}

	public static testMethod void testBatch() {
		GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(
			'SELECT id FROM lead limit 200'
		);
		id batchProcessId = database.executeBatch(batch);
	}
	
	public static testMethod void twoLeadsToOneContact() {
		
		Contact con = new Contact(
			FirstName = 'Fred',
			LastName = 'Flinstone_for_tests' 
		);
		insert con;
		
		Lead ld1 = new Lead(
			FirstName = 'Fred',
			LastName = 'Flinstone_for_tests',
			Company = 'Individual'
		);
		insert ld1;
	 
		Lead ld2 = new Lead(
			FirstName = 'Fred',
			LastName = 'Flinstone_for_tests',
			Company = 'Rock_Boulder_Industries'
		);
		insert ld2;
		
		Lead ld3 = new Lead(
			FirstName = 'Barney',
			LastName = 'Rubble_for_tests',
			Company = ONEN_Constants.NOT_PROVIDED_LABEL
		);
		insert ld3;
		
		Lead ld4 = new Lead(
			FirstName = 'Wilma',
			LastName = 'Flinstone_for_tests',
			Company = 'Individual'
		);
		insert ld4;
		
		Lead ld5 = new Lead(
			FirstName = 'Betty',
			LastName = 'Rubble_for_tests',
			Company = 'Rubble_Industries'
		);
		insert ld5;
		
		//describe call to get lead fields for dynamic SOQL
		Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
		
		String querySOQL = 'SELECT ';
    	querySOQL += '(select campaignid from campaignmembers order by createddate desc),';
        for (string fieldname : leadFieldMap.keyset()) {
        	querySOQL += fieldname + ', ';
        }
        querySOQL = querySOQL.substring(0,querySOQL.length()-2);   //lop off trailing comma
        querySOQL += ' FROM lead WHERE id IN (\'' + ld1.id + '\',\'' + ld2.id + '\',\'' + ld3.id + '\',\'' + ld4.id + '\',\'' + ld5.id + '\')';
        querySOQL += ' ORDER BY createddate'; 	
    	system.debug ('query string: ' + querySOQL);
		
		test.startTest();
		GW_BATCH_LeadConversion batch = new GW_BATCH_LeadConversion(querySOQL);
		id batchProcessId = database.executeBatch(batch);
		test.stopTest();
		
		List<contact> theRubbles = [select id from Contact where LastName = 'Rubble_for_tests'];
		system.AssertEquals(2, theRubbles.size());
		
		List<lead> convertedLeads = [SELECT id FROM lead WHERE (LastName = 'Flinstone_for_tests' OR LastName = 'Rubble_for_tests') AND isConverted = true];
		system.debug('Converted Leads ' + convertedLeads);
		//Wilma should not get converted because she has a last name match only
		system.AssertEquals(4, convertedLeads.size());
	}
}