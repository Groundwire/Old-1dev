trigger GW_Campaign_Eventbrite on Campaign (after update) {
// Written by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

/*
	list<campaign> campaignsWithEventPayments = new list<campaign>();
	
	for (campaign c : trigger.new) {
		if (//c.NumberOfContacts > 0 && 
			//trigger.oldMap.get(c.id).NumberOfContacts == 0 &&
			c.total_amount_paid__c > 0) 
			
		campaignsWithEventPayments.add(c);			
	}

	system.assert(campaignsWithEventPayments.isEmpty(), campaignsWithEventPayments.size());

	list<campaignMember> membersWithEventPayments = new list<campaignMember>();
	set<string> orderIds = new set<string>();
	set<string> contactIds = new set<string>();
	
	for (campaignMember cm : trigger.new) {
		if (cm.ebConnector__Amount_Paid__c != null && cm.ebConnector__Amount_Paid__c != 0 &&
				cm.ContactId != null && trigger.oldMap.get(cm.id).contactId == null) {
			membersWithEventPayments.add(cm);
			orderIds.add(cm.ebConnector__Order_ID__c);
			contactIds.add(cm.contactId);
		}
	}
	
	if (!membersWithEventPayments.isEmpty()) {
		GW_EventbriteOpportunities eo = new GW_EventbriteOpportunities();
		eo.processPayments(membersWithEventPayments, orderIds, contactIds);
	}
	*/
}