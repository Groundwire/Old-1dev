global class GW_RollupOppToAccountTest extends GW_ABS_Rollup {

	public GW_RollupOppToAccountTest (id parentRecId) {
		super (parentRecId);
	}
	
	public GW_RollupOppToAccountTest (string SOQL) {
		super (SOQL);
	}

	public GW_RollupOppToAccountTest (integer batchSz) {
		super (batchSz);
	}
	
	global override string setParentObjName() {
		return 'Account';
	}
	
	

	global override list<RollupSpec> setRollupSpecs() {
		list<RollupSpec> mySpecs = new list<RollupSpec>();
		
		// create a rollup spec, specifying the object that has the details to be rolled up, 
		// and the field in that table that relates it to the parent object
		RollupSpec rs = new RollupSpec('opportunity', 'accountId');
		
		// where clause elements
		rs.filter = 'isWon=true AND Amount != 0 AND Amount != null AND closeDate >= LAST_N_DAYS:365';
		
		// these let you pass in sets of filter strings to include or leave out		
		rs.setFiltersIn = new map<string, set<string>> {
			'RecordTypeId' => (new set<string>()) //recordTypesToExcludeAccts,
		};
		rs.setFiltersNotIn = new map<string, set<string>> {
			'RecordTypeId' => (new set<string>()), //recordTypesToExcludeAccts,
			'Type' => (new set<string>{'In Kind'} ) //oppTypesToExcludeAccts
		};
		
		// this maps aggregate functions to the rollup field names that summarize them
		rs.aggregateToParentFieldnameMap = new map<string, string> {
			'SUM(Amount)' => 'TotalOppAmount__c',
			'AVG(Amount)' => 'AverageAmount__c',
			'MIN(Amount)' => 'SmallestAmount__c',
			'MAX(Amount)' => 'LargestAmount__c',
			'MIN(CloseDate)' => 'FirstCloseDate__c',
			'MAX(CloseDate)' => 'LastCloseDate__c',
			'COUNT_DISTINCT(Id)' => 'NumberOfClosedOpps__c' 
		};		

		// if you set these, you must override the processSubgroup method to process each group
		rs.subgroupExpression = 'Fiscal_Year(closeDate)';
		
		// this maps each aggregate field to a map of subgroup values and the fields that summarize them
		rs.subgroupValueToParentFieldnameMap = new map<string, map<object, string>> {
			'SUM(Amount)' => new map<object, string> { 
				2011 => 'OppAmountThisYear__c', 
				2010 => 'OppAmountLastYear__c' 
			},
			'COUNT_DISTINCT(Id)' => new map<object, string> { 
				2011 => 'OppsClosedThisYear__c', 
				2010 => 'OppsClosedLastYear__c'
			}
		};		

		// optional having clause, to limit the subgroups
		rs.subgroupFilter = 'Fiscal_Year(closeDate) = null OR Fiscal_Year(closeDate) >= 2010';		
		
		mySpecs.add(rs);
		
		return mySpecs; 
	}	


	static testMethod void testGivingRollupAcct () {

		// create account
		account testacct = new account(name='testacct');
		insert testacct;
		opportunity newOpp =
			 new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', 
			 					ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			 					name = 'testopp', accountid = testacct.id, 
			 					stagename='Closed Won', closedate=system.today(), amount=33333);
		opportunity newOpp2 =
			 new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', 
			 					ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			 					name = 'testopp2', accountid = testacct.id, 
			 					stagename='Closed Won', closedate=system.today().addDays(2), amount=11111);		
 		insert new Opportunity[]{newOpp,newOpp2};
		
		// run the rollup
		Test.StartTest();
		GW_RollupOppToAccountTest rollup = new GW_RollupOppToAccountTest(testacct.id);
		rollup.runRollups();
		Test.StopTest();

		Account updatedAcct = [select id, totalOppAmount__c,LastCloseDate__c from account where id =: testacct.id];
		System.AssertEquals ( 44444 , updatedAcct.TotalOppAmount__c );
		System.AssertEquals ( system.today().addDays(2) , updatedAcct.LastCloseDate__c );
		
		/*
		// now delete the opp, and make sure the amount goes back to 0
		delete newOpp;
		updatedAcct = [select id, totalOppAmount__c from account where id =: testacct.id];
		//System.AssertEquals ( 0 , updatedAcct.TotalOppAmount__c );
		*/
	}	
	
	static testMethod void testGivingRollupAcctBatch () {

		// create account
		Account[] accts = ONEN_UnitTestData.CreateMultipleTestAccounts(40);
		// account testacct = new account(name='testacct');
		insert accts;

		// id oppRectype = GW_RecTypes.GetRecordTypeId('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		Opportunity[] opps1 = ONEN_UnitTestData.OppsForAccountList(accts, null, 'Closed Won', system.today(), 33333, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		Opportunity[] opps2 = ONEN_UnitTestData.OppsForAccountList(accts, null, 'Closed Won', system.today().addDays(2), 11111, ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		Opportunity[] allOpps = new Opportunity[0];
		allOpps.addAll(opps1);
		allOpps.addAll(opps2);
		insert allOpps;

/*		opportunity newOpp =
			 new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', 
			 					ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			 					name = 'testopp', accountid = testacct.id, 
			 					stagename='Closed Won', closedate=system.today(), amount=33333);
		opportunity newOpp2 =
			 new opportunity (RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', 
			 					ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			 					name = 'testopp2', accountid = testacct.id, 
			 					stagename='Closed Won', closedate=system.today().addDays(2), amount=11111);		
 		insert new Opportunity[]{newOpp,newOpp2};
*/
		
		// run the rollup
		Test.StartTest();
		GW_RollupOppToAccountTest rollup = new GW_RollupOppToAccountTest(20);
		rollup.customBatchWhereClause = 'WHERE Name LIKE \'%Yet Another Org%\'';
		rollup.runRollups();		// this should run batch automatically since we passed in a batch size
		Test.StopTest();

		Account[] updatedAccts = [select id, totalOppAmount__c,LastCloseDate__c from Account where id IN :accts];
		System.assertEquals(40, updatedAccts.size());
		for (Account acct:updatedAccts) {
			System.AssertEquals ( 44444 , acct.TotalOppAmount__c );
			System.AssertEquals ( system.today().addDays(2) , acct.LastCloseDate__c );
		}
	}
}