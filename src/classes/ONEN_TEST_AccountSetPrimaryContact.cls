@isTest 
private class ONEN_TEST_AccountSetPrimaryContact {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

//need to add a test to make sure we don't cross query limits with Accounts that have lots of contacts

	static testMethod void testAcctPrimaryContact() {
		
		Account testAcct;
	
		// try the function with no accts
		ONEN_AccountMaintenance.SetPrimaryContact(new Set<ID>());
	
		// first create two test accounts
		Id secondAcctId;
		Account firstAcct = new Account(Name='Blammo Corp');
		insert firstAcct;
		system.debug('Created account: ' + firstAcct.Id);
		Account secondAcct = new Account(Name='Funny Foundation');
		insert secondAcct;
		system.debug('Created account: ' + secondAcct.Id);
		
		// add a contact with a title in that account -- primary fields should get set
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen',
			Title='Head Honcho',
			AccountId=firstAcct.Id
		);
		insert firstContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: that contact should now be the primary contact on the Account
		system.assertEquals(testAcct.primary_contact__c, firstContact.id);
		//SWA: the Account should also show the title
			// MMS: deprecated
		// system.assertEquals(testAcct.primary_contact_title__c, 'Head Honcho');

		// add a contact without a title -- primary stays the same
		Contact secondContact = new Contact (
			FirstName='Cindy',
			LastName='LooHoo',
			AccountId=firstAcct.Id
		);
		insert secondContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: first contact should still be primary contact
		system.assertEquals(testAcct.primary_contact__c, firstContact.id);
		// MMS: deprecated
		//system.assertEquals(testAcct.primary_contact_title__c, 'Head Honcho');
				
		// delete the first contact -- primary changes to the second, title gets cleared
		delete firstContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: second contact should now be primary on that Account, has no title
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		// MMS: deprecated
		// system.assertEquals(testAcct.primary_contact_title__c, null);
		
		// add a third contact -- primary stays the same
		Contact thirdContact = new Contact (
			FirstName='John',
			LastName='Baptist',
			AccountId=firstAcct.Id
		);
		insert thirdContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		
		// move the third contact out of the other account and back -- primary still the same
		thirdContact.AccountId=null;
		update thirdContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		
		thirdContact.AccountId=firstAcct.Id;
		update thirdContact;
		
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		
		// move the second contact to the other account -- check for both primaries
			// MMS: at this pt, contact 2 should be the primary for BOTH accts
		secondContact.AccountId=secondAcct.Id;
		update secondContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);
		testAcct = [select id, name, primary_contact__c from account where id=:secondAcct.Id];
		//SWA: primary contact shouldn't change
		system.assertEquals(testAcct.primary_contact__c, secondContact.id);

		/* MMS: deprecated
		// add a title to the third contact -- should appear in account
		thirdContact.title='Apex Guru';
		update thirdContact;
		testAcct = [select id, name, primary_contact__c, primary_contact_title__c from account where id=:firstAcct.Id];
		//SWA: title of primary contact should change
		system.assertEquals(testAcct.primary_contact_title__c, thirdContact.title);

		// try removing the account's primary contact title -- it should come back
		firstAcct.primary_contact_title__c = null;
		update firstAcct;
		testAcct = [select id, name, primary_contact__c, primary_contact_title__c from account where id=:firstAcct.Id];
		//SWA: primary contact's title should refill if a user tries to remove it
		system.assertEquals(testAcct.primary_contact_title__c, thirdContact.title);
		*/

		// try removing the account's primary contact -- it should come back
		firstAcct.primary_contact__c = null;
		update firstAcct;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact should refill if a user tries to remove it
		system.assertEquals(testAcct.primary_contact__c, thirdContact.id);
		
		/* MMS: deprecated
		// try changing the account's primary contact to a contact outside the account -- change should not take
		firstAcct.primary_contact__c = secondContact.id;
		update firstAcct;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: primary contact has to be in the Account, so shouldn't change
		system.assertEquals(testAcct.primary_contact__c, thirdContact.id);
		*/

		// delete the third contact -- account should have no primary
		delete thirdContact;
		testAcct = [select id, name, primary_contact__c from account where id=:firstAcct.Id];
		//SWA: delete only contact from an Account shold remove the primary Contact info from the Account
		system.assertEquals(testAcct.primary_contact__c, null);
			
		// delete accounts
		Account[] testAccts = [select id from Account where name='Blammo Corp' or name='Funny Foundation'];
		system.Debug('Deleting ' + testAccts.size() + ' accounts.');
		delete testAccts;

	}
	
	static testMethod void testAcctPrimaryContactBULK() {
		
		// let's try it in bulk -- testing the governors
		Account[] a200 = new Account[]{};
		for (integer i=0;i<10;i++) {
			a200.add(new Account(Name='Test'+String.valueof(i)));
		}
		insert a200;
		Account[] a200more = new Account[]{};
		for (integer i=0;i<10;i++) {
			a200more.add(new Account(Name='Test'+String.valueof(i+10)));
		}
		insert a200more;
		Contact[] lotsaContacts = new Contact[]{};
		for (integer i=0;i<10;i++) {
			lotsaContacts.add(
				new Contact(				
					LastName='Test'+String.valueof(i),				
					AccountId=a200[i].id
				)
			);
		}
		test.starttest();
		insert lotsaContacts;
		for (integer i=0;i<10;i++) {
			lotsaContacts[i].AccountId=a200more[i].id;
		}
		update lotsaContacts;
		test.stoptest();
	}

}