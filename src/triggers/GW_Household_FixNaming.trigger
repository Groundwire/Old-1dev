trigger GW_Household_FixNaming on ONEN_household__c (before update) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	system.debug(logginglevel.warn, 'doing it');
	// if this update is from apex, don't perform the trigger
	if (!GW_Householding.nowUpdating) {
		
		// get all the contacts for these households
		contact[] allhc = [select id, onen_household__c, salutation, firstname, lastname, not_in_hh_name__c from contact where onen_household__c in :trigger.newmap.keyset() limit 800];			
		for (onen_household__c hh : trigger.new) {
			onen_household__c oldHH = trigger.oldmap.get(hh.id);
			
			// set the manual update fields
			if (hh.name != oldHH.name) {
				hh.auto_hhName__c = false;
			}
			if (hh.greeting__c != oldHH.greeting__c) {
				hh.auto_hhGreeting__c = false;
			}

			// get the contact list for this one household 
			contact[] hc = new contact[0];
			for (contact c : allhc) {
				if (c.onen_household__c == hh.id) hc.add(c);
			}
					
			// update names as needed
			GW_Householding gwhh = new GW_Householding();
			if (hh.auto_hhName__c) {
				hh.name = gwhh.getHHName(hc);
			}
			if (hh.auto_hhGreeting__c) {
				hh.greeting__c = gwhh.getHHGreeting(hc);
			}
	system.debug(logginglevel.warn, hh);
		}
	}
}