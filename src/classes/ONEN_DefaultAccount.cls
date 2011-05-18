// Written by Evan Callahan, copyright (c) 2011 Groundwire
public class ONEN_DefaultAccount {

    private static Id individualAccountId; 
    private static Id individualAcctForTests;

    public static final string individualAcctName =
    	 Test.isRunningTest() ? 'IndividualAccountForTests' : ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;
    	
	// method that returns the id of the individual account
    public static id getIndividualAccountId () {
    	
    	// tests should get a separate individual account
    	if (Test.isRunningTest()) {

    		// create a test account if we haven't already
    		if (individualAcctForTests == null)
	            individualAcctForTests = newAcct();

    		return individualAcctForTests;
    			
    	} else {
    			
			if ( individualAccountId == null ) {
	
		        // look up the stored ID if we haven't already done it
		        miscellaneousBaseSettings__c settings = miscellaneousBaseSettings__c.getInstance();
				if (settings != null && settings.Individual_Account_Id__c != null) {
					
					individualAccountId = settings.Individual_Account_Id__c;

				} else {				

		            Account[] acct = [select id from account where Name =:ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME LIMIT 1];
	            	individualAccountId = (acct.isEmpty()) ? newAcct() : acct[0].id;

				}              
	        }
	        return individualAccountId;
    	}
    }
    
    private static id newAcct() {
    	account a = new Account( name = individualAcctName );
    	
    	CRMfusionDBR101.DB_Globals.triggersDisabled = true;
	    insert a;
	    CRMfusionDBR101.DB_Globals.triggersDisabled = true;
    	
    	return a.id;
    }
    
    // DEPRECATED METHOD
    public static Id setIndividualAccountForTests(String accountName) { return GetIndividualAccountId(); }

	// TEST
	static testMethod void TestAccountAdd() {	
				 
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen_for_tests'			
		);
		insert firstContact;
		
		//the default Account should have been added to the contact
		Contact createdFirstContact = [select Account.Name from Contact where Id =:firstContact.id];
		System.assertEquals('IndividualAccountForTests', createdFirstContact.Account.Name);
	}
}