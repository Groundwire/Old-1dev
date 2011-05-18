public class ONEN_EXT_JobChangeWizard {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	id OldAccountId;
	
	Contact contact = new Contact();
	
	Account_Relationship__c relationship = new Account_Relationship__c (); 

    public ONEN_EXT_JobChangeWizard(ApexPages.StandardController controller) {
        this.contact = (Contact)controller.getRecord();
    	//capture the AccountId for the contact before it changes via the form
        OldAccountId = this.contact.AccountId;
        contact.AccountId = null;
	}

	//getter for the relationship object for the form
    public Account_Relationship__c  getRelationship() {
        if(relationship == null) relationship = new Account_Relationship__c ();
        return relationship;
    } 
    //getter for the contact
    public Contact getContact() {         
        if(contact == null) contact = new Contact();        
        return contact;
    }
    //save action
    public PageReference save() {
        try {
         	update contact;
         
	    } catch (DmlException e) {
            ApexPages.addMessages(e);   
            return null;         	         
	    }
          
        //if they aren't coming from the Individual Account, create the relationship
        if(OldAccountId <> ONEN_DefaultAccount.GetIndividualAccountId()) { 
	        relationship.Related_Account__c = OldAccountId;
	        relationship.Contact__c = contact.id;
	        relationship.Relationship__c = 'Employee';
	        
	        try {
     			insert relationship;
     
    		} catch (DmlException e) {
	            ApexPages.addMessages(e);   
	            return null;         	                  
    		}
	        
	        
        }
           
        PageReference p = new PageReference('/' + contact.id);
        //refresh page
        p.setRedirect(true);
        return p;
    }

}