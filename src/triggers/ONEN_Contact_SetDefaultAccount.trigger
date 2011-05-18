trigger ONEN_Contact_SetDefaultAccount on Contact (before insert, before update) {
// Written by Steve Andersen, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    //system.debug('AccountAdd FIRED');
    
    // new method to lookup individual acct id 
    Id DefaultAccountId = ONEN_DefaultAccount.GetIndividualAccountId();
     
    List<Contact> ContactsForUpdate = new List<Contact>();
    
    //this syntax handles the bulk nature of the trigger. Trigger.New is a list of Contacts
    //only process the Contacts if we have an Account Id to put on the record
    if(DefaultAccountId!=null) {
        for (Contact c : Trigger.New) {
            //if no AccountId was supplied on the inserted or updated contact, use the default one
            if (c.AccountId == NULL) {              
                //set the Account Id value to the default
                c.AccountId = DefaultAccountId;
                ContactsForUpdate.add(c);               
            } 
        }
    }
    if (ContactsForUpdate.size()>0) {
        //system.debug('AccountAdd EXECUTED');
    } else {
        //system.debug('AccountAdd NOT EXECUTED');
    }
    //since this is a before trigger, when it's done the contact will be inserted or updated
}