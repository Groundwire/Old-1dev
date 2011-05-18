trigger GW_Account_GeoDistrict on Account (before insert, before update, after insert, after update) {
// Written by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	GeocodingSettings__c geoSettings = GeocodingSettings__c.getInstance();
	if ((geoSettings != null && geoSettings.geocodeAccounts__c) || GW_Geocoder.isTest) {		

		list<id> acctids = new list<id>();
		list<string> addr = new list<string>();
	
		for (account a : trigger.new) {
			// only geocode if the address is new
			if (trigger.isinsert || a.BillingStreet != trigger.oldMap.get(a.id).BillingStreet || 
	    			a.BillingPostalCode != trigger.oldMap.get(a.id).BillingPostalCode || 
	    			a.BillingCity != trigger.oldMap.get(a.id).BillingCity) {
	    		
				// make sure that we are not out of future calls
				if (trigger.isBefore) {
					if (limits.getLimitFutureCalls() <= limits.getFutureCalls() )
						a.geocoding_status__c = '[' + system.today().format() + '] ' +
							'Limit of Apex asynchronous (@future) calls has been exceeded.';
				} else {	
					// build the address string
			        string address = '';
			        if (a.billingstreet != null) address += a.billingstreet + ', ';
			        if (a.billingcity != null) address += a.billingcity + ', ';
			        if (a.billingstate != null) address += a.billingstate + ' ';
			        if (a.billingpostalcode != null) address += a.billingpostalcode;
					
					// code it
			        acctids.add(a.id);
			        addr.add(address);    
				}
	    	}
		}
	
		if (!acctids.isEmpty())
			GW_Geocoder.updateAcctGeo( acctids, addr );
	}		
}