trigger ONEN_Lead_LeadToCampaign on Lead (after insert) {
// Written by Steve Andersen, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	Map<Id,Lead> leadsToProcess = new Map<Id,Lead>();
	for (Lead l : Trigger.new) {
		if (l.Campaign_Id__c != NULL||l.Contact_Id__c != NULL) {
			leadsToProcess.put(l.id,l);
		}
	}
	if(leadsToProcess.size()>0){ 
		
		//Map<Id,Lead> leadsToDelete = new Map<Id,Lead>();
		List<CampaignMember> membershipRecords = new list<CampaignMember>();
		for(Lead thisLead : leadsToProcess.values()) {
			//if (thisLead.Contact_Id__c != NULL) {
			//	leadsToDelete.put(thisLead.id,thisLead);				
			//}	
			if (thisLead.Campaign_Id__c != NULL) {	
				if (thisLead.Contact_Id__c != NULL) {
					CampaignMember cmContact = new CampaignMember (				
						CampaignId=thisLead.Campaign_Id__c,
						ContactId=thisLead.Contact_Id__c			
					);
					if (thisLead.Campaign_Member_Status__c!=null) {
						cmContact.Status=thisLead.Campaign_Member_Status__c;
					}
					membershipRecords.add(cmContact);
				} else {
					CampaignMember cmLead = new CampaignMember (				
						CampaignId=thisLead.Campaign_Id__c,
						LeadId=thisLead.Id			
					);
					if (thisLead.Campaign_Member_Status__c!=null) {
						cmLead.Status=thisLead.Campaign_Member_Status__c;
					}
					membershipRecords.add(cmLead);
				}	
			}	
		}
		if (membershipRecords.size()>0) {
			
		//	try {
				insert membershipRecords;
		//	} catch (System.DmlException e) {		
		//		for (Integer k = 0; k < e.getNumDml(); k++) {
		//			System.debug(e.getDmlMessage(k)); 
		//		}
		//	}
		}
		//if (leadsToDelete.size()>0) {
		//	try {
		//		delete leadsToDelete.values();
		//	} catch (System.DmlException e) {		
		//		for (Integer k = 0; k < e.getNumDml(); k++) {
		//			System.debug(e.getDmlMessage(k)); 
		//		}
		//	}
		//}
	}
}