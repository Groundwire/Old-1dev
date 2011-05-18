trigger ONEN_Account_SetPrimaryContact on Account (after update) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle 
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	//system.debug('ONEN_Account_SetPrimaryContact FIRED');
	// update primary contact for all the accounts that were changed
	Set<Id> acctIds = new Set<ID>();
	for (integer i = 0; i < Trigger.New.size(); i++) {
		// check to see if the primary contact was modified
			// mod 2/09 MMS - only look at contact, not Title
		Account aOld = Trigger.old[i];
		Account aNew = Trigger.new[i];
		if (aNew.primary_contact__c != aOld.primary_contact__c) {
	 		acctIds.add(aNew.Id);	
		}
	} 
	// call the update code for the set of accounts
	if (!acctIds.isEmpty()) {
		//system.debug('ONEN_Account_SetPrimaryContact EXECUTED');
		ONEN_AccountMaintenance.SetPrimaryContact(acctIds);
	} else {
		//system.debug('ONEN_Account_SetPrimaryContact DID NOT EXECUTE');	
	}
}