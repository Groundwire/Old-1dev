public class ONEN_UnitTestData { 
// Written by Matthew Scholtz, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

// create data for use in unit tests
// should not be referenced by production code

	Public static contact CreateTestContact (integer n) {
		
		// create one contact
		// integer identifies unique set of field values
		
		Contact newCon = New Contact ();
		
		if ( n == 1 ) {
			newCon.FirstName = 'Stringer';
			newCon.LastName = 'Bell';
			newCon.OtherCity = 'Baltimore';
		} else if (n==2) {
			newCon.FirstName = 'Avon';
			newCon.LastName = 'Barksdale';
			newCon.OtherCity = 'Baltimore';
		} else if (n==3) {
			newCon.FirstName = 'Lester';
			newCon.LastName = 'Freamon';
			newCon.OtherCity = 'Baltimore';
		}
		
//		insert newCon;
		return newCon;
	}
	
	Public static list<Contact> CreateMultipleTestContacts (integer n) {
		
		list<contact> ContactsToAdd = New list<contact> ();
		
		for (integer i=0;i<n;i++) {
			Contact newCon = New Contact (
				FirstName = 'Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
			);
			ContactsToAdd.add (newCon);
		}
		
		// testing doing the insert in the calling code - will maybe reinstate this
		//insert ContactsToAdd;
		
		return ContactsToAdd;
	}
	
	Public static list<Contact> CreateMultipleTestContactsInHouseholds (List<Contact> firstContactList) {
		
		list<contact> ContactsToAdd = New list<contact> ();
		
		for (integer i=0;i<firstContactList.size();i++) {
			Contact newCon = New Contact (
				FirstName = 'Second Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle',
				ONEN_Household__c = firstContactList[i].ONEN_Household__c
			);
			ContactsToAdd.add (newCon);
		}
		
		// testing doing the insert in the calling code - will maybe reinstate this
		//insert ContactsToAdd;
		
		return ContactsToAdd;
	}
	
	Public static list<Opportunity> OppsForContactList (list<Contact> Cons, id CampId, string Stage, date Close, double Amt, string rectype, string oppType) {
	 
		// given a list of Contacts,
		// add one Opp per contact w/ the specified data
		// TBD should allow specifying rectype (optional)
	
		list<Opportunity> OppsToAdd = new list<Opportunity> ();
		/* SWA 1/18/09 - replacing old record types calls with static ones
		// look up the id for the specified rectype
		ONEN_RecordTypes rtlookup = new ONEN_RecordTypes ('Opportunity');
		id rtid = rtlookup.GetRecordTypeId (rectype);
		*/
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',rectype);
		
		for ( Contact thisCon : Cons ) {
			Opportunity newOpp = New Opportunity (
				Name = 'Test Opp ' + thisCon.FirstName + thisCon.LastName,
				Amount = Amt,
				CloseDate = Close,
				StageName = Stage,
				CampaignId = CampId,
				CR_Contact_Id__c = thisCon.Id,
				CR_Contact_Role__c = 'Individual Donor',
				type = oppType,
				RecordTypeId = rtid
			);	
			OppsToAdd.add (newOpp);
		}
		
		return OppsToAdd;
		
	}
	


	Public static list<Account> CreateMultipleTestAccounts (integer n) {
		
		list<Account> AcctsToAdd = New list<Account> ();
		
		for (integer i=0;i<n;i++) {
			Account newAcct = New Account (
				Name = 'Yet Another Org ' + i
			);
			AcctsToAdd.add (newAcct);
		}
		
		return AcctsToAdd;
	}
	

		Public static list<Opportunity> OppsForAccountList (list<Account> Accts, id CampId, string Stage, date Close, double Amt, string rectype) {
	
		// given a list of accounts,
		// add one Opp per acct w/ the specified data
	
		list<Opportunity> OppsToAdd = new list<Opportunity> ();
		
		// look up the id for the specified rectype
		/* SWA 1/18/09 - replacing old record types calls with static ones
		
		ONEN_RecordTypes rtlookup = new ONEN_RecordTypes ('Opportunity');
		id rtid = rtlookup.GetRecordTypeId (rectype);
		*/
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',rectype);
		
		for ( Account thisAcct : Accts) {
			Opportunity newOpp = New Opportunity (
				AccountId = thisAcct.id,
				Name = 'Test Opp ' + thisAcct.Name,
				Amount = Amt,
				CloseDate = Close,
				StageName = Stage,
				CampaignId = CampId,
				RecordTypeId = rtid
			);	
			OppsToAdd.add (newOpp);
		}
		
		return OppsToAdd;
		
	}
	
	Public Static CampaignMember CreateCampaignMember (id CampId, id ConId, string CMStatus) {
	
		CampaignMember newCM = new CampaignMember (
			CampaignId = CampId,
			ContactId = ConId,
			Status = CMStatus
		);
		
		insert newCM;
		return newCm;	
		
	}
	
	
	public static void DeleteListCustomSettingRecs (string objname) {
		// given the name of a custom setting table, delete all the records in it
        string qstr = 'SELECT Id,Name FROM ' + objname;
        sObject[] srecs = Database.query(qstr);
        if (srecs.size() > 0) {
        	// first make sure this is really a custom setting obj
        	Schema.Sobjecttype t = srecs[0].getSObjectType();
        	Schema.Describesobjectresult d = t.getDescribe();
        	if ( d.isCustomSetting() ) {
        		// if so, delete all the recs
        		delete srecs;
        	}
        }
	}
	
}