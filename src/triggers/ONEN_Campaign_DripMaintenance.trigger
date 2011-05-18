trigger ONEN_Campaign_DripMaintenance on Campaign (after insert) {
// Written by Dave Manelski, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	if (Trigger.isInsert) {
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
		
		for (Campaign thisCampaign : trigger.new) {
			
			if ( thisCampaign.Type == 'Drip Campaign' ) {
					CampaignMemberStatus statusOne = new CampaignMemberStatus(
					Label = 'New',
					IsDefault = true,
					CampaignId = thisCampaign.id,
					HasResponded = false,
					SortOrder = 3
					);
					newStatuses.add(statusOne);		
					
					CampaignMemberStatus statusTwo = new CampaignMemberStatus(
					Label = 'In Progress',
					CampaignId = thisCampaign.id,
					HasResponded = true,
					SortOrder = 4
					);
					newStatuses.add(statusTwo);		
					
					CampaignMemberStatus statusThree = new CampaignMemberStatus(
					Label = 'Completed',
					CampaignId = thisCampaign.id,
					HasResponded = true,
					SortOrder = 5
					);
					newStatuses.add(statusThree);		
			}	
		}
		//create new statuses before deleting the old values
		if ( newStatuses.size() > 0 ) {
			insert newStatuses;	
		}
		//get all the old default statuses and delete them
		List<CampaignMemberStatus> oldStatuses = new List<CampaignMemberStatus>([select id, label from CampaignMemberStatus where CampaignId IN :trigger.new and (label = 'Sent' or label = 'Responded')]);
		if ( oldStatuses.size() > 0 && newStatuses.size() > 0 ) {
			delete oldStatuses;	
		}	
    }

}