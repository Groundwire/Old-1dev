@isTest 
private class ONEN_TEST_ContactMarkBadEmail {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	static testMethod void Contact_MarkedAsBadEmail () {
		
		//Create a new contact record with Bad Email Address (custom boolean field on Contact) unchecked
		Contact testContact = new Contact (
			LastName = 'Schmoe',
			Bad_Email_Address__c = false
		);
		insert testContact;
		
		// Assert that Bad Email Address is indeed false on our newly create contact record
		Contact testContact1 = [select id, Bad_Email_Address__c from Contact where id=:testContact.Id];
		system.assertEquals(false,testContact1.Bad_Email_Address__c);
		
		// Create a new Vertical Response email history record with the contact Id of the contact record created above
		// and with the Bounced checkbox unchecked (false)
		vr__VR_Email_History_Contact__c testEmailHistory = new vr__VR_Email_History_Contact__c (
			Name = 'Test Campaign Email',
			vr__Bounced__c = false,
			vr__Contact__c = testContact.Id
		);
		insert testEmailHistory;
		
		Contact testContact2 = [select id, Bad_Email_Address__c from Contact where id=:testContact.Id];
		
		// this shouldn't have triggered the code, so Contact should still be false
		system.assertEquals(false,testContact2.Bad_Email_Address__c); 
		
		// Create a new Vertical Response email history record with the contact Id of the contact record created above
		// and with the Bounced checkbox checked (true) -- this should kick off the trigger to update the contact record.
		vr__VR_Email_History_Contact__c testEmailHistory1 = new vr__VR_Email_History_Contact__c (
			Name = 'Test Campaign Email',
			vr__Bounced__c = true,
			vr__Contact__c = testContact.Id
		);
		insert testEmailHistory1;
		
		// Assert that the Bad Email address on the contact record has been set to true when the 
		// VR email history record is bounced 
		Contact testContact3 = [select id, Bad_Email_Address__c from Contact where id=:testContact.Id];
		system.assertEquals(true,testContact3.Bad_Email_Address__c);
	}
}