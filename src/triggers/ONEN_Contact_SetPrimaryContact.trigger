trigger ONEN_Contact_SetPrimaryContact on Contact (after delete, after insert, after update) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	CRMfusionDBR101.DB_Globals.triggersDisabled = true;

    //system.debug('ONEN_Contact_SetPrimaryContact FIRED');
    // update primary contact for all the accounts that were changed
    Set<Id> acctIds = new Set<ID>();

    for (integer i = 0; i < (Trigger.isDelete ? Trigger.old.size() : Trigger.new.size()); i++) {

        // get the old version
        Contact cOld; 
        if (!Trigger.IsInsert) {
            cOld = Trigger.old[i];
        }

        // get the new version
        Contact cNew;
        if (!Trigger.isDelete) {
            cNew = Trigger.new[i];
        }
         
        if (cOld!=null && cNew!=null) {
            
            // check if the person's account or title has changed
            if (cNew.AccountID != cOld.AccountID || cNew.Title != cOld.Title) {
    
                // update contacts old and new accounts, if they exist
                if (cOld.AccountId!=null) acctIds.add(cOld.AccountId);
                if (cNew.AccountId!=null) acctIds.add(cNew.AccountId);
            }
        } else {
            // update the accounts if there are any
            if (cOld!=null && cOld.AccountId!=null) acctIds.add(cOld.AccountId);
            if (cNew!=null && cNew.AccountId!=null) acctIds.add(cNew.AccountId);
        }
    }
    
    // call the update code for the set of accounts
    if (!acctIds.isEmpty()) {
    //  system.debug('ONEN_Contact_SetPrimaryContact EXECUTED');
        ONEN_AccountMaintenance.SetPrimaryContact(acctIds);
    }else {
    //  system.debug('ONEN_Contact_SetPrimaryContact DID NOT EXECUTE');
    } 
    
    CRMfusionDBR101.DB_Globals.triggersDisabled = false;
}