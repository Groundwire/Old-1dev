@isTest 
private class ONEN_TEST_OpportunitiesMarkAs {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public static testMethod void TestMarkAsWon() {
	  //create first contact
	  Contact firstContact = new Contact (
	  FirstName='Joe',
	  LastName='Schmoe_for_tests'
	  );
	  insert firstContact;
	
	//new opp for contact
	Opportunity firstOpp = new Opportunity (
		RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
		Name = 'Test first contact opp',
		amount=100,
		StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
		CloseDate=Date.newInstance(2005,10,10),
		CR_Contact_Id__c = firstContact.id,
		CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
	);
	
	insert firstOpp;
	
	List<Opportunity> selectedOpps = new List<Opportunity>();
	
	selectedOpps.add(firstOpp);
	
	PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
	Test.setCurrentPage(p);
	
	//pass selected opportunities into the controller
	ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
	sc.setSelected(selectedOpps);
	//pass the controller into the extension
	ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
	
	ext.MarkAsWon();
	
	Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id = :firstOpp.id ];
	system.assertEquals(1,Opps.size());
	System.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE,Opps[0].StageName);
	
	}
	
	
	public static testMethod void TestMarkAsThanked() {

	  //create first contact
	  Contact firstContact = new Contact (
	  FirstName='Joe',
	  LastName='Schmoe_for_tests'
	  );
	  insert firstContact;
	
	//new opp for contact
	Opportunity firstOpp = new Opportunity (
		RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
		Name = 'Test first contact opp',
		amount=100,
		StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
		CloseDate=Date.newInstance(2005,10,10),
		CR_Contact_Id__c = firstContact.id,
		CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
	);
	
	insert firstOpp;
	
	List<Opportunity> selectedOpps = new List<Opportunity>();
	
	selectedOpps.add(firstOpp);
	
	PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
	Test.setCurrentPage(p);
	
	//pass selected opportunities into the controller
	ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
	sc.setSelected(selectedOpps);
	//pass the controller into the extension
	ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
	
	ext.MarkAsThanked();
	
	Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id = :firstOpp.id ];
	system.assertEquals(1,Opps.size());
	System.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE,Opps[0].StageName);
	
	}

	public static testMethod void TestMarkAsLost() {
	
	  //create first contact
	  Contact firstContact = new Contact (
	  FirstName='Joe',
	  LastName='Schmoe_for_tests'
	  );
	  insert firstContact;
	
	//new opp for contact
	Opportunity firstOpp = new Opportunity (
		RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
		Name = 'Test first contact opp',
		amount=100,
		StageName=ONEN_Constants.OPP_DEFAULT_STAGE,
		CloseDate=Date.newInstance(2005,10,10),
		CR_Contact_Id__c = firstContact.id,
		CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
	);
	
	insert firstOpp;
	
	List<Opportunity> selectedOpps = new List<Opportunity>();
	
	selectedOpps.add(firstOpp);
	
	PageReference p = new PageReference('/' + firstContact.id + '?retURL=' + firstContact.id);
	Test.setCurrentPage(p);
	
	//pass selected opportunities into the controller
	ApexPages.StandardSetController sc = new ApexPages.standardSetController(selectedOpps);
	sc.setSelected(selectedOpps);
	//pass the controller into the extension
	ONEN_EXT_OpportunitiesMarkAs ext = new ONEN_EXT_OpportunitiesMarkAs(sc);
	
	ext.MarkAsLost();
	
	Opportunity[] Opps = [SELECT Name, StageName FROM Opportunity where id = :firstOpp.id ];
	system.assertEquals(1,Opps.size());
	System.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE,Opps[0].StageName);
	
	}
	
}