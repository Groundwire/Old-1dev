global class GW_BATCH_DataUtilities implements Database.Batchable<SObject> {
// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/** batch apex framework that allows various bulk data changes
*** which means they work on a huge number of records
***
*** to use this, grab the lines from one of the unit tests (between startTest and stopTest)
*** click system log, paste them in, and run
*** be sure to modify the query to specify the records you want to affect
*** AND take out the LIMIT 200 at the end of the query
***
*** Example:
		// delete all test contacts
	    GW_BATCH_DataUtilities batch = new GW_BATCH_DataUtilities( 
			'delete_all',
			'Select id from contact where name like \'test%\' '
		);
		id batchProcessId = database.executeBatch(batch);
		
*** Feel free to add your own actions to the class, but ALWAYS add a test that demonstrates
**/

	// send any kind of records here
	public String query { get; set; }
	
	// this must be one of the following codes:
	//  delete_all, change_owner, create_mirror_pmts, swap_addresses, clear_indiv_acct
	public String action { get; set; }
	
	// in case your process needs additional information
	public String[] args { get; set; }

	// constructors
	public GW_BATCH_DataUtilities(string a, string q) {
		action = a; 
		query = q; 
		
		// if you need arguments, add them to the args list
		args = new string[0];
	}

	global database.Querylocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);		 
	}

	global public void execute(Database.BatchableContext bc, Sobject[] result) {

		if (action == 'delete_all') {
			
			delete result;
			
		} else if (action == 'change_owner') {
			
			if (!args.isEmpty()) {
			
				// put the first argument into the owner id field
				for (sobject o : result) o.put('ownerid', args[0]);
			}
			update result;
					
		} else if (action == 'create_mirror_pmts') {
			
			// add mirror payments for these opps
			list<opppayment__c> ops =  new list<opppayment__c>();
			for (sobject o : result) {
				opportunity opp= (opportunity)(o);			
				ops.add(new opppayment__c(opportunity__c = opp.id, date__c=opp.closedate, amount__c = opp.amount, paid__c=opp.iswon)); 
			}
			insert ops;					
			
		} else if (action == 'swap_addresses') {
				
			list<contact> cons =  new list<contact>();
			for (sobject o : result) {
				contact c = (contact)(o);			
				
				// not everyone will have this address type field, of course
				// also in this case we can assume the address is home - needs to switch - 
				// UNLESS the mailing address type is set to work - then we leave it
				if (c.accountid != ONEN_DefaultAccount.GetIndividualAccountId()) {  // c.Mailing_Address_Type__c == 'Work') {
	
					c.Primary_Address__c = 'Work';
					
					if (c.mailingStreet == c.otherStreet && c.otherStreet != null) {
						c.otherStreet = null;
						c.otherCity = null;
						c.otherState =  null;
						c.otherPostalCode =  null;
						c.otherCountry =  null;
					}
					
				} else {
					
					c.Primary_Address__c = 'Home';
	
					string temp;				
					
					temp = c.mailingStreet;
					c.mailingStreet = c.otherStreet;
					c.otherStreet = temp;
					
					temp = c.mailingCity;
					c.mailingCity = c.otherCity;
					c.otherCity = temp;
					
					temp = c.mailingState;
					c.mailingState = c.otherState;
					c.otherState = temp;
					
					temp = c.mailingPostalCode;
					c.mailingPostalCode = c.otherPostalCode;
					c.otherPostalCode = temp;
					
					temp = c.mailingCountry;
					c.mailingCountry = c.otherCountry;
					c.otherCountry = temp;
					
					//these were in the old nonprofit template 
					//temp = c.Mailing_Address_Type__c;
					//c.Mailing_Address_Type__c = c.Other_Address_Type__c;
					//c.Other_Address_Type__c = temp;
					
					if (c.mailingStreet == c.otherStreet && c.otherStreet != null) {
						c.mailingStreet = null;
						c.mailingCity = null;
						c.mailingState =  null;
						c.mailingPostalCode =  null;
						c.mailingCountry =  null;
					}
				}
	
				cons.add(c); 
			}
			update cons;					
						
		} else if (action == 'zip_county') {
				
			list<contact> cons =  new list<contact>();
			for (sobject o : result) {
				contact c = (contact)(o);			
					
				// set counties et al from zips
				if (c.mailingPostalCode != null && (c.work_county__c == null || c.mailingCity == null)) {
					ONEN_ZipLookup zl = new ONEN_ZipLookup(c.mailingPostalCode);
					if (c.work_county__c == null) c.work_county__c = zl.getCounty();
					if (c.mailingCity == null) c.mailingCity = zl.getCity();
					if (c.mailingState == null) c.mailingState = zl.getState();
				}
				if (c.otherPostalCode != null && (c.home_county__c == null || c.otherCity == null)) {
					ONEN_ZipLookup zl = new ONEN_ZipLookup(c.otherPostalCode);
					if (c.home_county__c == null) c.home_county__c = zl.getCounty();
					if (c.otherCity == null) c.otherCity = zl.getCity();
					if (c.otherState == null) c.otherState = zl.getState();
				}
	
				cons.add(c); 
			}
			update cons;					
						
		}
	}

	global void finish(Database.BatchableContext bc) {
	}

	public static testMethod void test_delete_all() {		
		test.startTest();
		GW_BATCH_DataUtilities batch = new GW_BATCH_DataUtilities( 
			'delete_all',
			'Select id from contact where name like \'test%\' limit 200'
		);
		id batchProcessId = database.executeBatch(batch);
		test.stopTest();
	}

	public static testMethod void test_change_owner() {		
		test.startTest();
		GW_BATCH_DataUtilities batch = new GW_BATCH_DataUtilities( 
			'change_owner',
			'Select id from contact where name like \'test%\' limit 200'
		);
		
		// specify the new owner id
		// in this case, we change the owner to ME
		batch.args.add(UserInfo.getUserId());
		
		id batchProcessId = database.executeBatch(batch);
		test.stopTest();
	}
	
	public static testMethod void test_create_mirror_pmts() {		
		test.startTest();
		GW_BATCH_DataUtilities batch = new GW_BATCH_DataUtilities( 
			'create_mirror_pmts',
			'SELECT id, iswon, amount, closedate FROM opportunity limit 200'
		);
		id batchProcessId = database.executeBatch(batch);
		test.stopTest();
	}

	public static testMethod void test_swap_addresses() {		
		test.startTest();
		GW_BATCH_DataUtilities batch = new GW_BATCH_DataUtilities( 
			'swap_addresses',
			'Select id from contact where name like \'test%\' limit 200'
		);
		id batchProcessId = database.executeBatch(batch);
		test.stopTest();
	}

	public static testMethod void test_zip_county() {		
		test.startTest();
		GW_BATCH_DataUtilities batch = new GW_BATCH_DataUtilities( 
			'zip_county',
			'Select id from contact where name like \'test%\' limit 200'
		);
		id batchProcessId = database.executeBatch(batch);
		test.stopTest();
	}
}