@isTest 
private class ONEN_TEST_OpportunityContactRoles {
// Written by Matthew Scholtz, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	private static string GiftRectype = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
	
	static testMethod void testNewOppCRSingle () {
	
		Contact TestCon1 = ONEN_UnitTestData.CreateTestContact (1) ;
		insert TestCon1;
		
//		system.debug (TestCon1.id);
		
		Contact[] cons = new Contact[] {TestCon1};
		
		// insert an opp for this contact
		// this method puts the ConID into the proper field in Opp
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( cons, null, 'Closed Won', System.Today(), 100 , GiftRectype,null);
		insert newOpps;
		
		// test we got one opp back:
		System.assertEquals ( 1 , newOpps.size() );
		
//		system.debug (newOpps[0]);
		
		// test the opp has ConRole for our contact, and that they're the Primary
		Opportunity thisOpp = newOpps[0];
		OpportunityContactRole[] thisCR = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE ContactId = :thisOpp.CR_Contact_Id__c AND OpportunityId = :thisOpp.id ];
		
//		system.debug (thisCR[0]);
		
		System.assertEquals ( 1 , thisCR.size() );
		System.assertEquals ( true , thisCR[0].IsPrimary ) ;
		
		
	}
	
	static testMethod void testNewOppCRHouseholds () {
				
		Integer sizeOfTest = 10;
		Contact[] TestCon1 = ONEN_UnitTestData.CreateMultipleTestContacts (sizeOfTest) ;
		Test.StartTest();
		insert TestCon1;
		Test.StopTest();
		List<Id> createContactIds = new List<Id>();
		for (Contact firstContact : TestCon1) {
			createContactIds.add(firstContact.Id);
		}
		Contact[] TestCon1WithHoueshold = [Select Id, ONEN_Household__c from Contact where id in :createContactIds];
		//system.debug('first contacts with hh: ' + TestCon1WithHoueshold);
		Contact[] secondContacts = ONEN_UnitTestData.CreateMultipleTestContactsInHouseholds (TestCon1WithHoueshold);
		
		insert secondContacts;
		//system.debug('second contacts: ' + secondContacts);
		
		List<Id> secondContactIds = new List<Id>();
		for (Contact secondContact : secondContacts) {
			secondContactIds.add(secondContact.Id);
		}
		system.debug (secondContactIds);
		
		
		// insert an opp for this contact
		// this method puts the ConID into the proper field in Opp
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCon1, null, 'Closed Won', System.Today(), 100 , GiftRectype,null);
		insert newOpps;
		
		// test we got one opp back:
		System.assertEquals ( sizeOfTest , newOpps.size() );
		List<Id> createdOppIds = new List<Id>();
		for (Opportunity thisOpp : newOpps) {
			createdOppIds.add(thisOpp.Id);
		}
//		system.debug (newOpps[0]);
		
		// test the opp has ConRole for our contact, and that they're the Primary
		Opportunity thisOpp = newOpps[0];
		OpportunityContactRole[] theseCR = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE ContactId in :createContactIds AND OpportunityId in :createdOppIds ];
		
//		system.debug (thisCR[0]);
		
		System.assertEquals ( sizeOfTest , theseCR.size() );
		for(OpportunityContactRole thisCR : theseCR) {
			System.assertEquals ( true , thisCR.IsPrimary ) ;
			System.assertEquals ( 'Individual Donor' , thisCR.Role ) ;
		}
		
		
		OpportunityContactRole[] theseHouseholdCR = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE ContactId in :secondContactIds AND OpportunityId in :createdOppIds ];
		
		System.assertEquals ( sizeOfTest , theseHouseholdCR.size() );
		for(OpportunityContactRole thisHHCR : theseHouseholdCR) {
			System.assertEquals ( false , thisHHCR.IsPrimary ) ;
			System.assertEquals ( 'Individual Donor - Household Member' , thisHHCR.Role ) ;
		}
		
	}

	static testMethod void testNewOppCRMany () {
	
		List<id> OppIds = new List<id> ();
		integer howMany = 50;
	
		Contact[] TestCons = ONEN_UnitTestData.CreateMultipleTestContacts ( howMany ) ;
		insert TestCons;
		
		// this method puts the ConID into the proper field in Opp
		Opportunity[] newOpps = ONEN_UnitTestData.OppsForContactList ( TestCons, null, 'Closed Won', System.Today(), 100 , GiftRectype,null);


		Test.StartTest();
		insert newOpps;
		Test.StopTest();
		
		// test we got opps back:
		System.assertEquals ( howMany , newOpps.size() );
		
		// get a list of the opp id's created
		for ( Opportunity thisOpp : newOpps ) {
			OppIds.add (thisOpp.id);	
		}
		
		// find all corresponding opp CR's
		OpportunityContactRole[] newCRs = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId IN :OppIds ];
		
		// check we got the right number and that all of them are Primary
		System.assertEquals ( howMany , newCRs.size() );
		
		OpportunityContactRole[] newCRsPrimary = [SELECT id, ContactId, OpportunityId, IsPrimary, Role FROM OpportunityContactRole WHERE OpportunityId IN :OppIds and IsPrimary = true];
		System.assertEquals ( howMany , newCRsPrimary.size () );
	}
}