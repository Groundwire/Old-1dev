trigger ONEN_Contact_ZipLookup on Contact (before insert, before update) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	for (contact c : trigger.new) {
		
		// if there was a change to work zip, look it up
		contact old = trigger.isUpdate ? trigger.oldMap.get(c.id) : new Contact();
		if (c.mailingPostalCode != null && c.mailingPostalCode != old.mailingPostalCode) {

			ONEN_ZipLookup zl = new ONEN_ZipLookup(c.mailingPostalCode);
			
			// set city/state/county UNLESS a new value was manually entered
			if (c.work_county__c == null || c.work_county__c == old.work_county__c) 
				c.work_county__c = zl.getCounty();
			if (c.mailingCity == null || c.mailingCity == old.mailingCity) 
				c.mailingCity = zl.getCity();
			if (c.mailingState == null || c.mailingState == old.mailingState) 
				c.mailingState = zl.getState();
		}

		// if there was a change to home zip, look it up
		if (c.otherPostalCode != null && c.OtherPostalCode != old.OtherPostalCode) {
		 
			ONEN_ZipLookup zl = new ONEN_ZipLookup(c.otherPostalCode);

			// set city/state/county UNLESS a new value was manually entered
			if (c.home_county__c == null || c.home_county__c == old.home_county__c) 
				c.home_county__c = zl.getCounty();
			if (c.otherCity == null || c.otherCity == old.otherCity) 
				c.otherCity = zl.getCity();
			if (c.otherState == null || c.otherState == old.otherState) 
				c.otherState = zl.getState();
		}
	}
}