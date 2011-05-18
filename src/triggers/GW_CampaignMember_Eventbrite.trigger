trigger GW_CampaignMember_Eventbrite on CampaignMember (after insert) {
// if this is a paid event registration, copy opp fields back to the lead record 
// Written by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	list<lead> leadsWithEventPayments = new list<lead>();
	GW_EventbriteOpportunities EO;
	
	for (campaignMember cm : trigger.new) {
		if (cm.contactId == null && cm.ebConnector__Amount_Paid__c != null && cm.ebConnector__Amount_Paid__c != 0) {
			
			// instantiate the class only when we need it
			if (EO == null)	EO = new GW_EventbriteOpportunities();
			
			// build a lead record to update for this registration
			leadsWithEventPayments.add( EO.getLeadForUpdate( cm ) );
		}
	}
	
	if (!leadsWithEventPayments.isEmpty()) 
		update leadsWithEventPayments;
	

/*
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