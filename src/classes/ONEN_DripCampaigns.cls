public class ONEN_DripCampaigns {
// Written by Dave Manelski, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	public List<CampaignMember> newCampaignMemberships = new List<CampaignMember>();
	public List<Id> contactIdsToAddToDrip = new List<Id>();
	Id thisDripCampaignId;
	public List<CampaignMember> newDripContacts = new List<CampaignMember>();
	public List<Drip_Step__c> dripSteps = new List<Drip_Step__c>();
	public Drip_Event__c newDripEvent = new Drip_Event__c();
	public List<Drip_Step__c> stepsToCreate = new List<Drip_Step__c>();
	List<Drip_Step__c> newDripSteps = new List<Drip_Step__c>();
	List<Drip_Event__c> dripEventsToCreate = new List<Drip_Event__c>();
	public Integer dripStepCount;
	public Integer dripStepInterval;
	public String dripStepIntervalUnit;
	public String templateName;
	public Date sendDate = System.Today();
	public Drip_Step__c newDripStep;
	public Campaign thisCampaign;
	public Campaign bogusCampaign;
	public Boolean startToday;
	
	public List<CampaignMember> countOfCampaignMembers;
	public Integer limitForNewMembers;

	
	Public ONEN_DripCampaigns(Id campaignId) {
		thisDripCampaignId = campaignId;
		thisCampaign = [select id, IsActive from Campaign where Id = :campaignId];
		countOfCampaignMembers = [select id from CampaignMember where status='New' and CampaignId = :thisDripCampaignId];
	
		dripSteps = [Select Email_Template__c, Interval_Unit__c, Interval_Type__c, Campaign__c From Drip_Step__c where Campaign__c = :thisDripCampaignId];
	}
	  
	Public Boolean dripStepsToCreate() {
		Boolean success = true;
		stepsToCreate.clear();
		
		//loop through, creating drip steps for each interval
		for (Integer dripStepCounter=1;(dripStepCounter-1)<dripStepCount;dripStepCounter++) {				
					newDripStep = new Drip_Step__c (
						Email_Template__c = templateName,
						Interval_Unit__c = (dripStepInterval*dripStepCounter)-dripStepInterval,
						Interval_Type__c = dripStepIntervalUnit,
						Campaign__c = thisDripCampaignId
						);
					if ( startToday ) {
						newDripStep.Interval_Unit__c = (dripStepInterval*dripStepCounter)-dripStepInterval;
					} else {
						newDripStep.Interval_Unit__c = dripStepInterval*dripStepCounter;
					}
					stepsToCreate.add(newDripStep);
		}
		
		return success;
	}
	
	Public Boolean createDripSteps() {
		Boolean success = true;
		
		for ( Drip_Step__c thisStep: stepsToCreate ) {
			newDripSteps.add(thisStep);	
		}
		insert newDripSteps;
		return success;
	}

	Public Boolean addContactsToDrip() {
		Boolean success = true;
		sendDate = bogusCampaign.StartDate; 
		//get new contacts, but only the right number. set limit to what was chosen above
		//set start date based on what user picked
		newDripContacts = [Select id,ContactId,Status,Contact.Email From CampaignMember where status='New' and CampaignId = :thisDripCampaignId LIMIT 10];
		
		//loop through, putting drip events in a list
		for ( CampaignMember thisDripCandidate : newDripContacts ) {
			if ( thisDripCandidate.Contact.Email != null ) {
				for ( Drip_Step__c thisDripStep : dripSteps ) {
					Date thisSendDate;
					
					if (thisDripStep.Interval_Type__c=='Year(s)') {
		     			thisSendDate=sendDate.addYears(thisDripStep.Interval_Unit__c.intValue());
		     		} else if (thisDripStep.Interval_Type__c=='Month(s)') {
		     			thisSendDate=sendDate.addMonths(thisDripStep.Interval_Unit__c.intValue());
		     		} else if (thisDripStep.Interval_Type__c=='Week(s)') {
		     			thisSendDate=sendDate.addDays(thisDripStep.Interval_Unit__c.intValue()*7);
		     		}
					
					newDripEvent = new Drip_Event__c (
						Email_Template__c = thisDripStep.Email_Template__c,
						Send_Date__c = thisSendDate,
						Campaign__c = thisDripStep.Campaign__c,
						Contact__c = thisDripCandidate.ContactId,
						Active__c = thisCampaign.IsActive
						);
					
					dripEventsToCreate.add(newDripEvent);
				}
				thisDripCandidate.Status = 'In Progress';
			} else {
				//invalid email
				//change the campaign status to no email?	
			}
		}
		
		//insert drip events in batches of 200
		system.debug('drip events: '+dripEventsToCreate);
		//try {
			insert dripEventsToCreate;
			update newDripContacts;
		//} catch (DMLException e) {
		//	System.debug('ERROR inserting dripEvents: '+ e);
		//	success = false;
		//}
		
		return success;
	}
	
}