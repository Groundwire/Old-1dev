@isTest 
private class ONEN_TEST_LeadAddressFlagger {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	//test to see that nothing happens if the address flag isn't set
	public static testMethod void testLeadNullAddressFlag() {
		
		String leadStreet = '123 Elm St.';
		String leadCity = 'Seattle';
		String leadState = 'WA';
		String leadPostalCode = '98107';
		String leadCountry = 'USA';
		String leadPhone = '206-888-9999';
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Street=leadStreet,
			City=leadCity,
			State=leadState,
			PostalCode=leadPostalCode,
			Country=leadCountry,
			Phone=leadPhone,
			Address_Flag__c=null
		);

		insert firstLead;
		
		Lead firstLeadAfterUpdate = [select id,Street,City,State,PostalCode,Country,Phone,Home_Street__c,Home_City__c,Home_State__c,Home_PostalCode__c,Home_Country__c,Home_Phone__c from Lead where Id=:firstLead.Id];
		//check main address fields
		system.assertEquals(leadStreet,firstLead.Street);
		system.assertEquals(leadCity,firstLead.City);
		system.assertEquals(leadState,firstLead.State);
		system.assertEquals(leadPostalCode,firstLead.PostalCode);
		system.assertEquals(leadCountry,firstLead.Country);
		system.assertEquals(leadPhone,firstLead.Phone);
		//check home address fields
		system.assertEquals(null,firstLead.Home_Street__c);
		system.assertEquals(null,firstLead.Home_City__c);
		system.assertEquals(null,firstLead.Home_State__c);
		system.assertEquals(null,firstLead.Home_PostalCode__c);
		system.assertEquals(null,firstLead.Home_Country__c);
		system.assertEquals(null,firstLead.Home_Phone__c);
		
	}
	//test to see that a home address will get moved from main to home fields
	public static testMethod void testLeadHomeAddressFlag() {
		
		String leadStreet = '123 Elm St.';
		String leadCity = 'Seattle';
		String leadState = 'WA';
		String leadPostalCode = '98107';
		String leadCountry = 'USA';
		String leadPhone = '206-888-9999';
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Street=leadStreet,
			City=leadCity,
			State=leadState,
			PostalCode=leadPostalCode,
			Country=leadCountry,
			Phone=leadPhone,
			Address_Flag__c='Home'
		);

		insert firstLead;
		
		Lead firstLeadAfterUpdate = [select id,Street,City,State,PostalCode,Country,Phone,Home_Street__c,Home_City__c,Home_State__c,Home_PostalCode__c,Home_Country__c,Home_Phone__c from Lead where Id=:firstLead.Id];
		//check main address
		system.assertEquals(null,firstLeadAfterUpdate.Street);
		system.assertEquals(null,firstLeadAfterUpdate.City);
		system.assertEquals(null,firstLeadAfterUpdate.State);
		system.assertEquals(null,firstLeadAfterUpdate.PostalCode);
		system.assertEquals(null,firstLeadAfterUpdate.Country);
		system.assertEquals(null,firstLeadAfterUpdate.Phone);
		//check home address
		system.assertEquals(leadStreet,firstLeadAfterUpdate.Home_Street__c);
		system.assertEquals(leadCity,firstLeadAfterUpdate.Home_City__c);
		system.assertEquals(leadState,firstLeadAfterUpdate.Home_State__c);
		system.assertEquals(leadPostalCode,firstLeadAfterUpdate.Home_PostalCode__c);
		system.assertEquals(leadCountry,firstLeadAfterUpdate.Home_Country__c);
		system.assertEquals(leadPhone,firstLeadAfterUpdate.Home_Phone__c);
		
	}
	//test to see that home address won't move if home is selected and Home address
	//isn't null--meaning someone entered that data
	public static testMethod void testLeadHomeAddressFlagWithHomeAddress() {
		
		String leadStreet = '123 Elm St.';
		String leadCity = 'Seattle';
		String leadState = 'WA';
		String leadPostalCode = '98107';
		String leadCountry = 'USA';
		String leadPhone = '206-888-9999';
		
		String leadHomeStreet = '123 Oak St.';
		String leadHomeCity = 'Portland';
		String leadHomeState = 'OR';
		String leadHomePostalCode = '97443';
		String leadHomeCountry = 'USA';
		String leadHomePhone = '206-777-0000';
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Street=leadStreet,
			City=leadCity,
			State=leadState,
			PostalCode=leadPostalCode,
			Country=leadCountry,
			Phone=leadPhone,
			Address_Flag__c='Home',
			Home_Street__c=leadHomeStreet,
			Home_City__c=leadHomeCity,
			Home_State__c=leadHomeState,
			Home_PostalCode__c=leadHomePostalCode,
			Home_Country__c=leadHomeCountry,
			Home_Phone__c=leadHomePhone
		);

		insert firstLead;
		
		Lead firstLeadAfterUpdate = [select id,Street,City,State,PostalCode,Country,Phone,Home_Street__c,Home_City__c,Home_State__c,Home_PostalCode__c,Home_Country__c,Home_Phone__c from Lead where Id=:firstLead.Id];
		//check main address
		system.assertEquals(leadStreet,firstLeadAfterUpdate.Street);
		system.assertEquals(leadCity,firstLeadAfterUpdate.City);
		system.assertEquals(leadState,firstLeadAfterUpdate.State);
		system.assertEquals(leadPostalCode,firstLeadAfterUpdate.PostalCode);
		system.assertEquals(leadCountry,firstLeadAfterUpdate.Country);
		system.assertEquals(leadPhone,firstLeadAfterUpdate.Phone);
		//check home address
		system.assertEquals(leadHomeStreet,firstLeadAfterUpdate.Home_Street__c);
		system.assertEquals(leadHomeCity,firstLeadAfterUpdate.Home_City__c);
		system.assertEquals(leadHomeState,firstLeadAfterUpdate.Home_State__c);
		system.assertEquals(leadHomePostalCode,firstLeadAfterUpdate.Home_PostalCode__c);
		system.assertEquals(leadHomeCountry,firstLeadAfterUpdate.Home_Country__c);
		system.assertEquals(leadHomePhone,firstLeadAfterUpdate.Home_Phone__c);
		
	}
}