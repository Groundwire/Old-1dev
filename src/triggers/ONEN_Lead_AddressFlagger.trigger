trigger ONEN_Lead_AddressFlagger on Lead (before insert) {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	//string to hold the flag
	String addressFlag;
	//loop through the new leads
	for (Lead thisLead : Trigger.New) {
		//get address flag
		addressFlag = thisLead.Address_Flag__c;
		//if Address flag is not null, and Home address isn't filled out put the main address in home fields
		if(addressFlag=='Home' && thisLead.Home_Street__c==null) {
			//swap addresses
			thisLead.Home_Street__c = thisLead.Street;
			thisLead.Home_City__c = thisLead.City;
			thisLead.Home_State__c = thisLead.State;
			thisLead.Home_PostalCode__c = thisLead.PostalCode;
			thisLead.Home_Country__c = thisLead.Country;
			thisLead.Home_Phone__c = thisLead.Phone;
			//set main address to null
			thisLead.Street = null;
			thisLead.City = null;
			thisLead.State = null;
			thisLead.PostalCode = null;
			thisLead.Country = null;
			thisLead.Phone = null;
		}
	}
}