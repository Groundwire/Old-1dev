global class GW_BATCH_CombineCampaigns implements Database.Batchable<SObject> {
// Batch apex class that adds or removes a large number of campaign members to or from a target campaign 
// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public String query { get; set; }			// this must be campaign members, including id, campaignid, contactid, and leadid 
	public Id targetCampaign { get; set; } 		// id of the campaign that gets affected
	public String memberStatus { get; set; }    // if adding, put a valid status for the target campaign here
	public string notifyEmail { get; set; }		// errors go here
	
	public set<id> allCampaignIds { get; set; } // ids of all campaigns	
	public set<id> addSet { get; set; }   		// ids of campaigns with members to add	
	public set<id> subtractSet { get; set; }	// ids of campaigns with members to exclude
	
	// these control whether members must be in ALL campaigns in order to be added or excluded
	public boolean intersectionForAdds { get; set; }
	public boolean intersectionForSubtracts { get; set; }

	// where clauses for member status filter
	public string addFilter { get; set; }		
	public string excludeFilter { get; set; }	// errors go here
	
	global database.Querylocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);		 
	}

	global public void execute(Database.BatchableContext bc, Sobject[] scope) {
		
		// get the set of up to 200 contact or lead ids included in this batch
		set<id> batch = new set<id>();
		for (sobject sobj : scope) batch.add((id)(sobj.get('id')));
			
		list<campaignMember> membersToRemove = new list<campaignMember>();
		list<campaignMember> membersToAdd = new list<campaignMember>();

		list<sobject> membersToAvoid;
		set<id> avoidSet = new set<id>();
			
		boolean isContact = (scope[0].getSObjectType() == Contact.sObjectType);
			
		try {
			
			if (subtractSet !=null && !subtractSet.isEmpty()) {

				// get ids of contacts and lead that are in all selected campaigns to exclude
				if (isContact) { 
					membersToAvoid = database.query(
						'select contactid from campaignmember where contactid != null and ' +
						'contactid in : batch ' +
						'and campaignid in : subtractSet ' + excludeFilter + 
						' group by contactid' +
						(intersectionForSubtracts ? 
							' having count_distinct(campaignid) = : subtractSet.size()' : '') );
				} else {
					membersToAvoid = database.query(
						'select leadid from campaignmember where leadid != null and ' + 
						'leadid in : batch ' +
						'and lead.isConverted = false ' +  
						'and campaignid in : subtractSet ' + excludeFilter + 
						' group by leadid' +
						(intersectionForSubtracts ? 
							' having count_distinct(campaignid) = : subtractSet.size()' : '') );
				}

				// add the ids to sets
				for (sobject cm : membersToAvoid) avoidSet.add((id)(cm.get(isContact ? 'contactId' : 'leadId')));
				
				// get members of the target campaign that we want to remove
				membersToRemove = [select id from campaignmember where campaignid = : targetCampaign
										and (contactId in : avoidSet or leadId in :avoidSet)];
			}
	
			list<campaignMember> existingMembers;
			list<sobject> memberObjects;
			set<id> existingIds = new set<id>();
			
			if (addSet != null && !addSet.isEmpty()) {
				// get existing lead and contact ids from the target campaign, so we can avoid dupes
				existingMembers = [select id, contactid, leadId from campaignmember 
										where (contactId in : batch or leadId in :batch)
										and campaignid = : targetCampaign ];
	
				for (campaignMember cm : existingMembers) {
					if (cm.contactId != null) existingIds.add(cm.contactId);
					if (cm.leadId != null) existingIds.add(cm.leadId);
				}
	
				if (isContact) { 
					memberObjects = database.query(
						'select contactid from campaignmember where contactid != null and ' +
						'contactid in : batch ' +
						'and contactid not in : existingIds ' +
						'and contactid not in : avoidSet ' +
						'and campaignid in : addSet ' + addFilter + 
						' group by contactid' +
						(intersectionForAdds ? 
							' having count_distinct(campaignid) = : addSet.size()' : '') );
				} else {
					memberObjects = database.query(
						'select leadid from campaignmember where leadid != null and ' + 
						'leadid in : batch ' +
						'and leadid not in : existingIds ' +
						'and leadid not in : avoidSet ' +
						'and lead.isConverted = false ' +  
						'and campaignid in : addSet ' + addFilter + 
						' group by leadid' +
						(intersectionForAdds ? 
							' having count_distinct(campaignid) = : addSet.size()' : '') );
				}
					
				// create new member records to add to the target campaign
				for (sobject cm : memberObjects) {
					// bail out if there are too many
					CampaignMember newCM = new CampaignMember(
							campaignId = targetCampaign,
							status = memberStatus
					);
					if (isContact) {
						newCM.contactId = (id)(cm.get('contactId'));
					} else {
						newCM.leadId = (id)(cm.get('leadId'));
					}
					membersToAdd.add(newCM);
				}
			}
			
			if (!membersToAdd.isEmpty()) insert membersToAdd;
			if (!membersToRemove.isEmpty()) delete membersToRemove;
			
		} catch (exception e) { 
			system.debug('BATCH APEX ERROR: ' + e.getMessage());
			emailError(e.getMessage());
		} 
	}
	
	global void finish(Database.BatchableContext bc) {
	}
	
	void emailError(string msg) {	
		if (notifyEmail != null) {
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setToAddresses(new String[] { notifyEmail });
			mail.setReplyTo( notifyEmail );
			mail.setSenderDisplayName('Salesforce Batch Processing');
			mail.setSubject('Batch apex error in GW_BATCH_CombineCampaigns class');
			mail.setPlainTextBody(msg);
			Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
		}
	}
	
	public static testMethod void testBatchApexCampaignCombiner() {

		// create test data
		Contact[] testCons = New list<contact> ();
		
		for (integer i=0;i<60;i++) {
			Contact newCon = New Contact (
				FirstName = 'Number' + i,
				LastName = 'Doppleganger',
				OtherCity = 'Seattle'
			);
			testCons.add (newCon);
		}
		insert testCons;		

		lead testLead = new lead(lastname='Cale', firstname='JJ', company='[not provided]');
		insert testLead;

		Campaign cmp0 = new Campaign (
			Name='Target',
			IsActive=true
		);
		insert cmp0;
		Campaign cmp1 = new Campaign (
			Name='Add1',
			IsActive=true
		);
		insert cmp1;
		Campaign cmp2 = new Campaign (
			Name='Add2',
			IsActive=true
		);
		insert cmp2;
		Campaign cmp3 = new Campaign (
			Name='Subtract',
			IsActive=true
		);
		insert cmp3;
		
		// add a few contacts to each campaign - some should overlap
		campaignmember[] cms = new campaignmember[0];
		for (integer i = 0; i < 60; i++) {
			id cmpId = (i<5) ? cmp0.id : (i<30) ? cmp1.id : (i<40) ? cmp3.id : cmp2.id; 
			cms.add(new campaignmember(campaignId = cmpId, contactId = testCons[i].id));
			if ((i>=50 && i<55) || i==0) cms.add(new campaignmember(campaignId = cmp1.Id, contactId = testCons[i].id));
			if ((i>=55 && i<60) || i<3) cms.add(new campaignmember(campaignId = cmp3.Id, contactId = testCons[i].id));
		}
		cms.add(new campaignmember(campaignId = cmp1.Id, leadId = testLead.id));					
		insert cms;
		
		Test.startTest();
	 		
		GW_BATCH_CombineCampaigns bcc;
		
		// instantiate the class
		bcc = new GW_BATCH_CombineCampaigns();
		
		// set the target campagin
		bcc.targetCampaign = cmp0.id;
	 	bcc.notifyEmail = 'test@test.com'; 
	 			
	 	// set the batch query text
		bcc.query = 'SELECT id FROM contact WHERE id IN (select contactId from campaignMember WHERE campaignId IN (\'' + cmp1.id + '\',\'' + cmp2.id + '\',\'' + cmp3.id + '\')) limit 200'; 
		
		// tell it the status we want 
		bcc.memberStatus = 'Sent';

		// do the batch
		bcc.addSet = new set<id>{cmp1.id, cmp2.id}; 
		bcc.subtractSet = new set<id>{cmp3.id}; 
	 	system.debug('QUEUING: ' + bcc.query);
		id batchProcessId = Database.executeBatch(bcc, 200);

		bcc.query = 'SELECT id FROM lead WHERE id IN (select leadId from campaignMember where campaignId IN (\'' + cmp1.id + '\',\'' + cmp2.id + '\',\'' + cmp3.id + '\')) limit 200';
		bcc.addSet = new set<id>{cmp1.id, cmp2.id}; 
		bcc.subtractSet = new set<id>{cmp3.id}; 
	 	system.debug('QUEUING: ' + bcc.query);
		bcc.targetCampaign = cmp0.id;
		batchProcessId = Database.executeBatch(bcc, 200);
		
		// see if it is happening
		AsyncApexJob[] jobs = [Select Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems From AsyncApexJob where id = : batchProcessId];
		system.assert(jobs != null);
		system.assertNotEquals('Failed', jobs[0].status);

		// do it again with intersection
		bcc.query = 'SELECT id FROM contact WHERE id IN (select contactId from campaignMember WHERE campaignId IN (\'' + cmp1.id + '\',\'' + cmp2.id + '\',\'' + cmp3.id + '\')) limit 200'; 
	 	system.debug('QUEUING INTERSECTION: ' + bcc.query);
		bcc.addSet = new set<id>{cmp1.id, cmp2.id}; 
		bcc.subtractSet = new set<id>{cmp3.id}; 
	 	bcc.intersectionForAdds = true;
	 	bcc.intersectionForSubtracts = true;
		bcc.targetCampaign = cmp0.id;
		batchProcessId = Database.executeBatch(bcc, 200);

		// this is critical - otherwise no test runs
		Test.stopTest();		

		jobs = [Select Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems From AsyncApexJob where id = : batchProcessId];
		system.assert(jobs != null);
		system.assertNotEquals('Failed', jobs[0].status);
	
	}	
	
	public static testMethod void testBatchApexCampaignCombinerError() {

		// create test data
		Campaign cmp0 = new Campaign (
			Name='Target',
			IsActive=true
		);
		insert cmp0;
		
		Test.startTest();
	 		
		GW_BATCH_CombineCampaigns bcc;
		
		// instantiate the class
		bcc = new GW_BATCH_CombineCampaigns();
	 	bcc.notifyEmail = 'test@test.com'; 
	 			
	 	// set the batch query text
		bcc.query = 'SELECT  Id FROM CampaignMember limit 200';
		bcc.addSet = new set<id>{ cmp0.id };
		
		// tell it the status we want 
		bcc.memberStatus = 'Went';

		// do the error
	 	system.debug('QUEUING: ' + bcc.query);
		id batchProcessId = Database.executeBatch(bcc, 200);

		// this is critical - otherwise no test runs
		Test.stopTest();		
		system.assertEquals('test@test.com', bcc.notifyEmail); 
	}		

}