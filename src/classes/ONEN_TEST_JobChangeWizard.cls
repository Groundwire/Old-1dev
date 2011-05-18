@isTest 
private class ONEN_TEST_JobChangeWizard {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

 	static testMethod void ONEN_Test_Changing_The_Job() {  
		  
		Test.setCurrentPageReference(new PageReference('Page.Job_Change'));		 
		Id oldAccountId;
		Id newAccountId; 
		  
		//create first account
		Account oldAccount = new Account (
			name='XYZ Organization'
		);
		insert oldAccount;
		oldAccountId = oldAccount.id;
		  
		//create first contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Schmoe',
			AccountId=oldAccountId  
		);
		insert firstContact;
		  
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(firstContact);
		//pass the controller into the extension
		ONEN_EXT_JobChangeWizard ext = new ONEN_EXT_JobChangeWizard(sc);  
		    
		//create second account
		Account newAccount = new Account (
			name='ABC Organization'
		);
		insert newAccount;
		  
		newAccountId = newAccount.id; 
		   
		//Get the contact from the extension and associate it with a new account
		ext.getContact().AccountId = newAccountId;
		//Call the save method to save the page and activate the extension
		String savePage = ext.save().getUrl();
		  
		Contact createdContact = [select Account.Name from Contact where Id =:firstContact.id];
		   
		//Test to see if the contact now has the new AccountId
		System.assertEquals('ABC Organization',createdContact.Account.Name);
		   
		Account_Relationship__c relationship = [select id, Contact__c, Relationship__c, Related_Account__c, To_Date__c from Account_Relationship__c where Contact__c = :firstContact.id limit 1]; 
		  
		//Test to see if the child record that get created has the old Org. Id and apprpriate relationship type
		System.assertEquals(oldAccountId,relationship.Related_Account__c);
		System.assertEquals('Employee',relationship.Relationship__c);
		  
		  
	}
 
 	static testMethod void ONEN_Test_Changing_The_Job_from_individual() {  
		//the relationship shouldn't be created if the contact was in the
		//individual account
		Test.setCurrentPageReference(new PageReference('Page.Job_Change'));
		 
		Id newAccountId; 
		  		  
		//create first contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Schmoe',
			AccountId=ONEN_DefaultAccount.GetIndividualAccountId() 
		);
		insert firstContact;
		  
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(firstContact);
		//pass the controller into the extension
		ONEN_EXT_JobChangeWizard ext = new ONEN_EXT_JobChangeWizard(sc);  
		    
		//create second account
		Account newAccount = new Account (
			name='ABC Organization'
		);
		insert newAccount;
		  
		newAccountId = newAccount.id; 
		   
		//Get the contact from the extension and associate it with a new account
		ext.getContact().AccountId = newAccountId;
		//Call the save method to save the page and activate the extension
		String savePage = ext.save().getUrl();
		   
		Account_Relationship__c[] relationship = [select id, Contact__c, Related_Account__c, Relationship__c, To_Date__c from Account_Relationship__c where Contact__c = :firstContact.id limit 1]; 
		  
		//Test to see that the relationship wasn't created
		System.assertEquals(0,relationship.size());		  
		  
 	}
}