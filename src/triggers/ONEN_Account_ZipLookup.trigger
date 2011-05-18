trigger ONEN_Account_ZipLookup on Account (before insert, before update) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	/*
	for (account a : trigger.new) {
		if (a.billingPostalCode != null && (a.county__c == null || a.billingCity == null || a.billingState == null)) {
			ZipLookup zl = new ZipLookup(a.billingPostalCode);
			if (a.county__c == null) a.county__c = zl.getCounty();
			if (a.billingCity == null) a.billingCity = zl.getCity();
			if (a.billingState == null) a.billingState = zl.getState();
		}
		if (a.shippingPostalCode != null && (a.shippingCity == null || a.shippingState == null)) {
			ZipLookup zl = new ZipLookup(a.shippingPostalCode);
			if (a.shippingCity == null) a.shippingCity = zl.getCity();
			if (a.shippingState == null) a.shippingState = zl.getState();
		}
	}
	*/
}