trigger GW_Contact_GeoDistrict on Contact (before insert, before update, after insert, after update) {
// Written by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	GeocodingSettings__c geoSettings = GeocodingSettings__c.getInstance();
	if ((geoSettings != null && geoSettings.geocodeContacts__c) || GW_Geocoder.isTest) {		

		list<id> conids = new list<id>();
		list<string> addr = new list<string>();
	
		for (contact c : trigger.new) {
			// only geocode if the address is new
			contact old = trigger.isInsert ? null : trigger.oldMap.get(c.id);
			if (trigger.isInsert || c.otherStreet != old.otherStreet || 
	    			c.otherPostalCode != old.otherPostalCode || 
	    			c.otherCity != old.otherCity ||
	    			(c.latitude__c == null && 
	    				(c.mailingStreet != old.mailingStreet || 
	    				 c.mailingPostalCode != old.mailingPostalCode || 
	    				 c.mailingCity != old.mailingCity) 
	    			)) {
		    		
				// make sure that we are not out of future calls
				if (trigger.isBefore) {
					if (limits.getLimitFutureCalls() <= limits.getFutureCalls() )
						c.geocoding_status__c = '[' + system.today().format() + '] ' +
							'Limit of Apex asynchronous (@future) calls has been exceeded.';
				} else {	
		    		// build the address
			        string address = '';
			        if (c.otherStreet != null) address += c.otherStreet + ', ';
			        if (c.othercity != null) address += c.othercity + ', ';
			        if (c.otherstate != null) address += c.otherstate + ' ';
			        if (c.otherpostalcode != null) address += c.otherpostalcode;
					if (address.trim()=='') {
				        if (c.mailingstreet != null) address += c.mailingstreet + ', ';
				        if (c.mailingcity != null) address += c.mailingcity + ', ';
				        if (c.mailingstate != null) address += c.mailingstate + ' ';
				        if (c.mailingpostalcode != null) address += c.mailingpostalcode;
					}
		
					// code it
			        conids.add(c.id);
			        addr.add(address);    
				}
	   		}
		}
		
		if (!conids.isEmpty())
		GW_Geocoder.updateContactGeo( conids, addr );
	}
}