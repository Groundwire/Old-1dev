trigger ONEN_Opportunity_AddToCampaign on Opportunity (after insert, after update) {
// Written by Matthew Scholtz, copyright (c) 2007 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	// when we first end up w/ a closedwon Opp that has a campaign source, 
	// ensure that the primary contact has a campaign mbrship for that campaign set to Responded
	// don't worry about opp deletions - don't ever remove camp mbrship once created
	// note: this doesn't prevent user from later removing camp mbr or changing it to not responded - that's OK I think
	// also note: won't trigger if user later changes primary contact on opp - that's probably OK too

	//system.debug ( 'TRIGGER FIRED');

	string DefaultDonatedStatus = ONEN_Constants.CAMPAIGN_DEFAULT_DONATED_STATUS;
	Set<id> allOppIds = new Set<id> ();
	Map<id,id> OppToContactIds = new Map<id,id> (); 
	// Map<id,Map<id,CampaignMember>> ContactToCMs = new Map<id,Map<id,CampaignMember>> ();
	Map<id,Opportunity> oppsToProcess = new Map<id,Opportunity> ();
	List<CampaignMember> CMsToInsert = new List<CampaignMember> ();
	List<CampaignMember> CMsToUpdate = new List<CampaignMember> ();
	
	// this map's keys will be a concatenation of contactID & campaignID 
	Map<string,CampaignMember> comboIDMap = new Map<string,CampaignMember> ();
	
	// use a set for this because it will automatically dedup
	Set<id> CampaignsToCheckCMS = new Set<id> ();
	Set<id> CampToCheckResponded = new Set<id> ();
	Set<id> CMIDsToUpdateSet = new set<id> ();
	Set<id> CampaignIds = new set<id> ();
	
	// load settings for opp types
	set<id> recordTypesToExcludeAccts = new set<id>();
	set<id> recordTypesToExcludeCons = new set<id>();
	set<string> oppTypesToExcludeAccts = new set<string>();
	set<string> oppTypesToExcludeCons = new set<string>();	
    OppRollupSettings__c rollupSettings = OppRollupSettings__c.getInstance();
	if (rollupSettings != null) {
		if (rollupSettings.Excluded_Contact_Opp_Rectypes__c != null) {
			set<string> rtNamesToExclude = new set<string>(rollupSettings.Excluded_Contact_Opp_Rectypes__c.split(';'));
			recordTypesToExcludeCons = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);
		}
		if (rollupSettings.Excluded_Account_Opp_Rectypes__c != null) {
			set<string> rtNamesToExclude = new set<string>(rollupSettings.Excluded_Account_Opp_Rectypes__c.split(';'));
			recordTypesToExcludeAccts = GW_RecTypes.GetRecordTypeIdSet('Opportunity', rtNamesToExclude);
		}
		if (rollupSettings.Excluded_Contact_Opp_Types__c != null) {
			oppTypesToExcludeCons = new set<string>(rollupSettings.Excluded_Contact_Opp_Types__c.split(';'));
		}
		if (rollupSettings.Excluded_Account_Opp_Types__c != null) {
			oppTypesToExcludeAccts = new set<string>(rollupSettings.Excluded_Contact_Opp_Types__c.split(';'));
		}
	}
	
	// first, make sure we have checked for contact role creation if necessary
	// (have to do this here to insure triggers happen in the right order)
	if ( Trigger.isInsert && ONEN_OpportunityContactRoles.haveCheckedContactRoles == false ) {
		ONEN_OpportunityContactRoles.CheckContactRoles ( trigger.newmap );	
	}
	
	// first figure out which opps need processing - only want contact opps whose
	for ( Opportunity opp : Trigger.new ) {
		boolean isChgd = false;
		if (trigger.isUpdate) {
			Opportunity oldOpp = trigger.oldmap.get(opp.Id);
			if (oldOpp.CampaignID != opp.CampaignID || oldOpp.StageName != opp.StageName) isChgd = true;
		}
		if ( opp.CampaignID != Null && opp.AccountID==null && (Trigger.IsInsert || isChgd )) {	
			oppsToProcess.put (opp.id, opp);
			CampaignIds.add(opp.CampaignId);	
		}
	}
	
	If ( oppsToProcess.size() > 0 ) {
	
		// * get set of oppID's in trigger.new
		// and pass set to OppContactRoles.getPrimaryContactID, returns map PrimaryContacts (OppID -> ContactID)
		allOppIds = oppsToProcess.keySet();
		OppToContactIds = ONEN_OpportunityContactRoles.GetPrimaryContactIdsBulk (allOppIds);
	
		//system.debug ('oppToContactIds map: ' + OppToContactIds);
		
		// map combos of contact & camp ID's to the CM's
		for (CampaignMember thisCM : [Select Id, ContactId, CampaignId, Status, HasResponded From CampaignMember WHERE ContactId IN :OppToContactIds.values() AND CampaignId IN :CampaignIds]) {
			string comboID = thisCM.ContactID + '|' + thisCM.CampaignID;
			comboIDMap.put (comboID,thisCM);
		}
		system.debug('This CampaignMember: ' + comboIDMap);
		
		// now loop through all of our opps
		for (Opportunity thisOpp : oppsToProcess.values() ) {
			
			id ConId = OppToContactIds.get(thisOpp.Id);
			id CampId = thisOpp.CampaignId;

			// but only process those that actually have a primary contact			
			if ( ConId != null) {
				CampaignMember thisCM;
				string comboID = ConId + '|' + CampId;
				thisCM = comboIDMap.get(comboID);

				boolean isNotGift = (thisOpp.accountId == null && 
					(recordTypesToExcludeCons.contains(thisOpp.RecordTypeId) ||
					oppTypesToExcludeCons.contains(thisOpp.Type))) ||
					(thisOpp.accountId != null && 
					(recordTypesToExcludeAccts.contains(thisOpp.RecordTypeId) ||
					oppTypesToExcludeAccts.contains(thisOpp.Type)));

				// if this contact doesn't already have a CM for this campaign, create one				
				if ( thisCM == null ) {
					CampaignMember newCM = new CampaignMember(
						ContactId = ConId ,
						CampaignId = CampId						
					);
					//use the default status unless the opp is won, then use the default donated status if it's a gift
					if (thisOpp.IsWon == True) {						
						If ( isNotGift ) {
							newCM.Status = 'Responded';
							CampToCheckResponded.add (CampId);
						} else {
							newCM.Status = DefaultDonatedStatus;
							CampaignsToCheckCMS.add (CampId);
						}
					}
					CMsToInsert.add (newCM);
					comboIDMap.put (comboID,newCM);

					
				} else {
					// if they do already have a CM, chg the status where appropriate
					if ( thisCM.HasResponded == true || thisOpp.IsWon == false) {
						// if already responded, or not won, do nothing
					} else {
						If ( isNotGift ) {
							thisCM.Status = 'Responded';
							CampToCheckResponded.add (CampId);
						} else {
							thisCM.Status = DefaultDonatedStatus;
							CampaignsToCheckCMS.add (CampId);
						}
						if (CMIDsToUpdateSet.add(thisCM.Id)) {
							CMsToUpdate.add(thisCM);
						}
					}
				}
			}
		}
		
		// check list of Campaigns that they have the Donated status, add if not
		// last param means we require that the status be HasResponded, and change it to that if it's not 
		// already
		boolean statusOK = ONEN_CampaignMemberStatus.CheckCMStatusExistsBulk (CampaignsToCheckCMS,DefaultDonatedStatus,true);
		boolean statusOK2 = ONEN_CampaignMemberStatus.CheckCMStatusExistsBulk (CampToCheckResponded,'Responded',true);
		
		//system.debug ('to update: ' + CMsToUpdate);
		//system.debug ('to insert: ' + CMsToInsert);

		// need to insert the new ones first, in case any will be subsequent dups that need updating.
		if ( CMsToInsert.size() > 0 ) {
			insert CMsToInsert;
		}	
		system.debug('CMDebug: ' + CMsToUpdate);	
		if ( CMsToUpdate.size() > 0 ) {
			update CMsToUpdate;		
		}
		
	}
}