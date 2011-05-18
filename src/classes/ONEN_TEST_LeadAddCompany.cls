@isTest 
private class ONEN_TEST_LeadAddCompany {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	static testMethod void TestLeadAdd() {	 

		//create first contact
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen'		
		);
		insert firstLead;
		
		Lead thisLead = [select Company from Lead where Id =:firstLead.id];

		//the Company should be not provided
		System.assertEquals(ONEN_Constants.NOT_PROVIDED_LABEL,thisLead.Company);
		
		//create second contact
		Lead secondLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company = 'Test Company'		
		);
		insert secondLead;
		
		Lead thisSecondLead = [select Company from Lead where Id =:secondLead.id];

		//the company should be what we set
		System.assertEquals('Test Company',thisSecondLead.Company);
		
		//blank out company
		thisSecondLead.Company = '';
		
		update thisSecondLead;
		
		Lead thisSecondLeadAfterUpdate = [select Company from Lead where Id =:secondLead.id];

		//the company should be not provided
		System.assertEquals(ONEN_Constants.NOT_PROVIDED_LABEL,thisSecondLeadAfterUpdate.Company);
		
		
	}
}