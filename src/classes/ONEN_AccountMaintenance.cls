public class ONEN_AccountMaintenance {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// Modifications by Matthew Scholtz, copyright (c) 2009 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	// mod 2/09 MMS: allow off-brand primary contacts, and don't record title
	  
	public static boolean firstRun = true;
	 
	// this function sets a primary contact for each account you pass in -- and fixes the primary
    public static void SetPrimaryContact(set<Id> acctIds) {
    	//SWA: added support for ignoring default account
    	//SWA: get default account id
		// new method to lookup individual acct id
		Id DefaultAccountId = ONEN_DefaultAccount.GetIndividualAccountId();
		system.debug ('defaultaccountID: ' + DefaultAccountId);		
		
	   	// don't allow recursion
	   	if (firstrun) {	   		
	    	firstRun = false; 
	
			// get the accounts in the set
			Account[] accts = [select id, primary_contact__c from account where id IN :acctIds];
			
			// added MMS
			set<id> existingPCs = new set<id>();
			for ( Account thisAcct : accts) {
				if (thisAcct.primary_contact__c != null) {
					existingPCs.add (thisAcct.primary_contact__c);
				}
			}
				
			// get all the contacts for the accounts in the set
			//SWA: add criteria to ignore contacts in the default account
			//SWA: need to deal with large return sets. Will get soql return set limits at some point
			
			// chgd MMS
			Contact[] cons = new list<Contact>();
			if ( ! (existingPCs.size() > 0) ) {
				cons = [select id, accountid, title from contact where (accountid IN :acctIds and AccountId!=:DefaultAccountId)  order by accountid, createddate];
			} else {
				cons = [select id, accountid, title from contact where (accountid IN :acctIds and AccountId!=:DefaultAccountId) OR Id IN :existingPCs order by accountid, createddate];
			}

			Map<Id, Contact> cMap = new Map<Id, Contact>();
			cMap.PutAll(cons);			

			// loop through the contacts to assign one to each account
			Map<Id, Id> primaryMap = new Map<Id, Id>();
			for (integer i=0; i<cons.size(); i++) {
				if (!primaryMap.containsKey(cons[i].accountid)) {
					primaryMap.put(cons[i].accountid, cons[i].id);
				}
			}
			
			// create a list of accounts that need updates
			Account[] upAccts = new Account[]{};
			
			// loop through the accounts
			for (Account a : accts) {
				//SWA: ignore the default account
				if (a.Id!=DefaultAccountId) {
					Id pcid = a.primary_contact__c;
					// String pct = a.primary_contact_title__c;   #MMS: don't worry about title
					
					// first, check to make sure the contact is in this account
				   	if (pcid != null) {
			   			if (cMap.containsKey(pcid) && cMap.get(pcid).AccountId==a.id) {
		   				} else {
							// not in the account, so clear the primary contact
							// MMS 10/14/08 don't do this for SX, allow off-brand primaries
							// pcid = null;
				   		}
				   	}
				
					// now get a new contact if needed
				   	if (pcid == null) {
				   		if (primaryMap.containsKey(a.id)) {
				   			pcid = primaryMap.get(a.id);
				   		}
					}
					
					// update the account if necessary
						// MMS: only look at contact, not title
					if (pcid != a.primary_contact__c ) {
						upAccts.add(
							new Account (
								id = a.id,
								primary_contact__c = pcid
								// primary_contact_title__c = pct
							)
						);
					}
				}
			}
			// now do the update
			system.debug('Updating ' + upAccts.size() + ' accounts.');
			if (!upAccts.isEmpty()) {
				// if using Dupeblocker, uncomment the following line, and the one 2 lines down from that
				//CRMfusionDBR101.DB_Globals.triggersDisabled = true;
				Update upAccts;
				//CRMfusionDBR101.DB_Globals.triggersDisabled = false;
			}
	   	}
	   	firstrun=true;
	}
	
	public static integer getIndAcctCount (string indAcctName) {
		integer count = database.countquery('SELECT count() FROM Account WHERE Name=\'' + indAcctName + '\'');
		if (count == null) {
			count = 0;
		}
		return count;
	}
}