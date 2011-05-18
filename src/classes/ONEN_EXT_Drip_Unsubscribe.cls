public class ONEN_EXT_Drip_Unsubscribe {
// Written by Dave Manelski, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	Campaign campaignWithEvents;
	Id CampaignId;
	List<Drip_Event__c> eventsToUpdate = new List<Drip_Event__c>();
	List<Drip_Event__c> eventsToDelete = new List<Drip_Event__c>();
	public String contactEmail {get {return contactEmail;} set { contactEmail=value;}}
	public Drip_Event__c event {get {return event;} set { event=value;}}
	public Boolean globalUnsub {get {return globalUnsub;} set {globalUnsub=value;}}
	public Boolean removeFromCampaign {get {return removeFromCampaign;} set {removeFromCampaign=value;}}
	
	public Boolean conNotInCampaign {get{return conNotInCampaign;}set{conNotInCampaign=value;}}

	public ONEN_EXT_Drip_Unsubscribe(ApexPages.StandardController controller) {
        this.campaignWithEvents = (Campaign)controller.getRecord();
        event = new Drip_Event__c();
        CampaignId = this.campaignWithEvents.id;
        
        //set two advanced settings checkboxes to false in the constructor
        globalUnsub = false;
        removeFromCampaign = false;
    }
    
    
    public PageReference Unsubscribe() {
        
        list<Drip_Event__c> eventsInCampaign = new list<Drip_Event__c>([select id, Active__c, Contact__c, Contact__r.Email, Completed_Date__c from Drip_Event__c where (Contact__r.Email = :contactEmail or Contact__c = :event.Contact__c) and Campaign__c = :CampaignId and Completed_Date__c = null]);
        system.debug('List of events to update: ' + eventsInCampaign);
        system.debug('Campaign to update ' + CampaignId);
        for ( Drip_Event__c thisEvent : eventsInCampaign ) {
        	thisEvent = new Drip_Event__c (
        		id = thisEvent.id,
        		Active__c = false
        	);
        	//add drip events to a list to update (make inactive) unless
        	//removing the campaignMember from the Campaign, then delete the upcoming drip events entirely
        	if (removeFromCampaign)  {
        		eventsToDelete.add(thisEvent);
        	} else {
        		eventsToUpdate.add(thisEvent);
        	}
        	
        }
        system.debug('Events to Update: ' + eventsToUpdate);
        
        //Set Email Opt Out to TRUE if checkbox on VF page is checked
        if (globalUnsub) {
        	list<Contact> contactsOptOut;
        	
        	//to prevent querying for contacts without an email address, eliminate them from the SOQL
        	if (contactEmail == null || contactEmail == '') {
        		contactsOptOut = new list<Contact>([select id, HasOptedOutOfEmail from Contact where id = :event.Contact__c]);
        	} else {
        		contactsOptOut = new list<Contact>([select id, HasOptedOutOfEmail from Contact where id = :event.Contact__c or Email = :contactEmail]);
        	}
        	list<Contact> contactsToUpdate = new List<Contact>();
        	for ( Contact thisContact : contactsOptOut ) {
        		thisContact = new Contact (
        			id = thisContact.id,
        			HasOptedOutOfEmail = true
        		);
        		contactsToUpdate.add(thisContact);
        	}
        	if (contactsToUpdate.size()>0) {
        		update contactsToUpdate;
        	}
        }
        
        //Remove contacts from campaign if checkbox on VF page is checked
        if (removeFromCampaign) {
        	list<CampaignMember> membersToDelete = new List<CampaignMember>();
        	if (event.Contact__c != null) {
	        	list<CampaignMember> removals = new list<CampaignMember>([select id from CampaignMember where ContactId = :event.Contact__c and CampaignId = :CampaignId]);	    
	        	   	for ( CampaignMember thisMember : removals ) {
	        		thisMember = new CampaignMember (
	        			id = thisMember.id
	        		);
	        		membersToDelete.add(thisMember);
	        	}
	        	
        	} else {
        		list<Contact> contactsOptOut = new list<Contact>([select id from Contact where Email = :contactEmail limit 1]);
        		if (contactsOptOut.size() > 0) {
	        		list<CampaignMember> removals = new list<CampaignMember>([select id from CampaignMember where ContactId = :contactsOptOut[0].id and CampaignId = :CampaignId]);
		        	for ( CampaignMember thisMember : removals ) {
		        		thisMember = new CampaignMember (
		        			id = thisMember.id
		        		);
		        		membersToDelete.add(thisMember);
		        	}
        		}
        		
        	}
        	if (membersToDelete.size()>0) {
        		delete membersToDelete;
        	}
        }
        
        //perform updates or deletions to Drip events and return user to the campaign record
        if ( eventsToUpdate.size() > 0 || eventsToDelete.size() > 0) {
        	if ( eventsToUpdate.size() > 0 ) {
        		update eventsToUpdate;
        	} else if (eventsToDelete.size() > 0) {
        		delete eventsToDelete;
        	}
        	PageReference p = new PageReference('/' + CampaignId);
        	p.setRedirect(true);
        	return p;
        } else {
        	conNotInCampaign = true;
        	return null;
        }    
        
    }
    
    /* TESTS */
    
    static testmethod void TestUnsubscribeActiveContact() {
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.dripUnsubscribe'));
		
		//create an campaign
		Campaign dripCampaign = new Campaign (
			Name='Test Drip',
			Type='Drip Campaign',
			IsActive=true
			);
		
		insert dripCampaign;
		
		//create a contact to add to the drip campaign
		Contact contactInDrip = new Contact (
			LastName = 'Schmoe_for_tests'
		);
		insert contactInDrip;	
		
		//create a second contact, not in the drip campaign
		Contact contactNotInDrip = new Contact (
			LastName = 'Jackson_for_tests'
		);
		insert contactNotInDrip;	
		
		//insert first contact into the drip campaign
		CampaignMember newCampaignMember = new CampaignMember (
			ContactId = contactInDrip.Id,
			CampaignId = dripCampaign.id,
			Status='In Progress'
		);
		insert newCampaignMember;
		
		//create drip event to test unsubscribe from
		Drip_Event__c eventForFirstContact = new Drip_Event__c (
			Send_Date__c = system.today(),
			Campaign__c = dripCampaign.id,
			Contact__c = contactInDrip.Id,
			Active__c = true
		);
		insert eventForFirstContact;
		
		//pass campaign into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(dripCampaign);
		//pass the controller into the extension
		ONEN_EXT_Drip_Unsubscribe ext = new ONEN_EXT_Drip_Unsubscribe(sc);
		
		//set the contact to unsubscribe
		ext.event.Contact__c = contactInDrip.id;

		list<Drip_Event__c> newEvents = new list<Drip_Event__c>([select id, Active__c, Contact__c, Campaign__c from Drip_Event__c where Contact__c = :eventForFirstContact.Contact__c and Campaign__c = :dripCampaign.id]);
		system.AssertEquals(1,newEvents.size());
		system.AssertNotEquals(0,newEvents.size());
		system.AssertEquals(true,newEvents[0].Active__c);
		system.AssertEquals(contactInDrip.id,newEvents[0].Contact__c);
		system.AssertEquals(dripCampaign.id,newEvents[0].Campaign__c);
		
		PageReference unsubscribeResult = ext.Unsubscribe();
		system.AssertNotEquals(null,unsubscribeResult);
			
		Drip_Event__c eventToTest = [select id, Active__c from Drip_Event__c where id = :eventForFirstContact.id];
		
		system.AssertEquals(false,eventToTest.Active__c);
				
	}
	
	static testmethod void TestRemoveFromCampaign() {
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.dripUnsubscribe'));
		
		//create an campaign
		Campaign dripCampaign = new Campaign (
			Name='Test Drip',
			Type='Drip Campaign',
			IsActive=true
			);
		
		insert dripCampaign;
		
		//create a contact to add to the drip campaign
		Contact contactInDrip = new Contact (
			LastName = 'Schmoe_for_tests',
			Email = 'Schmoe_for_tests@joe.org',
			HasOptedOutOfEmail = false
		);
		insert contactInDrip;		
		
		//insert first contact into the drip campaign
		CampaignMember newCampaignMember = new CampaignMember (
			ContactId = contactInDrip.Id,
			CampaignId = dripCampaign.id,
			Status='In Progress'
		);
		insert newCampaignMember;
		
		//create drip event to test unsubscribe from
		Drip_Event__c eventForFirstContact = new Drip_Event__c (
			Send_Date__c = system.today(),
			Campaign__c = dripCampaign.id,
			Contact__c = contactInDrip.Id,
			Active__c = true
		);
		insert eventForFirstContact;
		
		//pass campaign into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(dripCampaign);
		//pass the controller into the extension
		ONEN_EXT_Drip_Unsubscribe ext = new ONEN_EXT_Drip_Unsubscribe(sc);
		
		//set the contact to unsubscribe
		ext.contactEmail = contactInDrip.Email;
		ext.removeFromCampaign = true;
		ext.globalUnsub = true;
		PageReference unsubscribeResult = ext.Unsubscribe();

		list<Drip_Event__c> newEvents = new list<Drip_Event__c>([select id, Active__c, Contact__c, Campaign__c from Drip_Event__c where Contact__c = :eventForFirstContact.Contact__c and Campaign__c = :dripCampaign.id and Completed_Date__c = null]);
		system.AssertEquals(0,newEvents.size());
		
		list<Contact> unsubbedContacts = new list<Contact>([select id, HasOptedOutOfEmail from Contact where id = :contactInDrip.id limit 1]);
		system.AssertEquals(true,unsubbedContacts[0].HasOptedOutOfEmail);
		
		list<CampaignMember> removedMembers = new list<CampaignMember>([select ContactId, CampaignId from CampaignMember where ContactId = :contactInDrip.id and CampaignId = :dripCampaign.id limit 1]);
		system.AssertEquals(0,removedMembers.size());		
	}
	
	static testmethod void TestUnsubscribeNonCampaignMember() {
	
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.dripUnsubscribe'));
		
		//create an campaign
		Campaign dripCampaign = new Campaign (
			Name='Test Drip',
			Type='Drip Campaign',
			IsActive=true
			);
		
		insert dripCampaign;
		
		//create a second contact, not in the drip campaign
		Contact contactNotInDrip = new Contact (
			LastName = 'Jackson_for_tests'
		);
		insert contactNotInDrip;	

		//pass campaign into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(dripCampaign);
		//pass the controller into the extension
		ONEN_EXT_Drip_Unsubscribe ext = new ONEN_EXT_Drip_Unsubscribe(sc);
		
		//set the contact to unsubscribe
		ext.event.Contact__c = contactNotInDrip.id;

		list<Drip_Event__c> newEvents = new list<Drip_Event__c>([select id, Active__c, Contact__c, Campaign__c from Drip_Event__c where Contact__c = :contactNotInDrip.id and Campaign__c = :dripCampaign.id]);
		system.AssertEquals(0,newEvents.size());
		
		
		ext.event.Contact__c = contactNotInDrip.id;
		PageReference unsubscribeResult2 = ext.Unsubscribe();
		
		list<Drip_Event__c> newEventsNoContacts = new list<Drip_Event__c>([select id, Active__c, Contact__c, Campaign__c from Drip_Event__c where Contact__c = :contactNotInDrip.id and Campaign__c = :dripCampaign.id]);
		system.AssertEquals(0,newEventsNoContacts.size());
		system.AssertEquals(true,ext.conNotInCampaign);		
		system.AssertEquals(null,unsubscribeResult2);
		
	}
    
}