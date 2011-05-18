trigger GW_Household_PreventDeletion on ONEN_household__c (before delete) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	// if this update is from apex, don't perform the trigger
	if (!GW_Householding.nowUpdating) {
		
		// prevent user from deleting households unless they are already empty
			
		// first get the set of non-empty households
		set<id> hhids = new set<id>{};
		for (contact c : [select onen_household__c from contact 
								where onen_household__c in :trigger.oldmap.keyset() 
								limit 1000]) {
			hhids.add(c.onen_household__c);
		}
			
		// now add an error for each one that's in the non-empty list
		for (onen_household__c h : trigger.old) { 
			if (hhids.contains(h.id)) 
				h.addError('You cannot delete households that contain existing contacts. Instead, delete the contacts or clear their household field.');
		}
	}	

}