public with sharing class GW_CTRL_CampaignCombiner {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* controller for campaign combiner visualforce page
* allows combining campaigns by adding and subtracting members
*
* page can be called with or without optional parameter as follows:
*   /apex/CampaignCombiner?id=[target-campaign-id]
*
-----------------------------------------------------------------------------------------------*/

	// error emails during batch processing go here; set to null for no email
	public final string NOTIFY_EMAIL = null;  							
	
	// we use batch processing if total members are greater than this
	public integer BATCH_CUTOFF = 1000;   					

	// properties for page
	public integer wizardStep { get; private set; }
	public string newCampaignName { get; set; }
	public campaign targetCampaign { get; set; }
	public campaign[] campaignsToAdd { get; set; }
	public campaign[] campaignsToSubtract { get; set; }
	public campaign targetCampaignPicker { get; set; }
	public campaign campaignToAddPicker { get; set; }
	public campaign campaignToSubtractPicker { get; set; }
	public string addMemberStatus { get; set; }   		// use this to limit the status of members added
	public string excludeMemberStatus { get; set; }  	// use this to limit the status of members excluded
	public string newMemberStatus { get; set; }   		// use this to set the status for new members
	public string defaultStatus { get; private set; }
	public integer adds { get { return (campaignsToAdd == null) ? 0 : campaignsToAdd.size(); } }
	public integer subtracts { get { return (campaignsToSubtract == null) ? 0 : campaignsToSubtract.size(); } }
	public boolean intersectionForAdds { get; set; }       // checkbox for "add only if in all campaigns"
	public boolean intersectionForSubtracts { get; set; }	
	public string resultMessage { get; private set; }
	public integer batchJobCount { get; private set; }	   // 0=no batch, 1=batching leads OR contact, 2=batching leads AND contacts
	public string batchLabel { get; private set; }
	public integer membersAdded { get; private set; }
	public integer membersRemoved { get; private set; }
	public boolean done { get; set; }
    public List<SelectOption> allMemberStatuses { get; private set; }

	// unique ids of selected campaigns
	set<id> addSet;
	set<id> subtractSet;

	// for batch apex
	GW_BATCH_CombineCampaigns bcc;
	Id batchProcessId;
	
	// constructor
	public GW_CTRL_CampaignCombiner() {
		// get parameter if any
		id cid;
		try {
			cid = ApexPages.currentPage().getParameters().get('id');
		} catch (exception e) {		
		}  
		
		// set other page properties
		campaignsToAdd = new campaign[0];
		campaignsToSubtract = new campaign[0];
		targetCampaign = new campaign(name='Dummy');
		targetCampaignPicker = new campaign(name='Dummy', parentId=cid);
		campaignToAddPicker = new campaign(name='Dummy');
		campaignToSubtractPicker = new campaign(name='Dummy');
		intersectionForAdds = false;
		intersectionForSubtracts = false;
		wizardStep = 1;
		batchJobCount = 0;
		done = false;

		// load unique member statuses
        allMemberStatuses = new SelectOption[0];
   		allMemberStatuses.add(new SelectOption('','- Any Status -'));
   		allMemberStatuses.add(new SelectOption('AllResponded','- All Responded -'));
   		allMemberStatuses.add(new SelectOption('AllNotResponded','- All Not Responded -'));
   		allMemberStatuses.add(new SelectOption('Sent','Sent'));
   		allMemberStatuses.add(new SelectOption('Responded','Responded'));
   		set<string> cmsSet = new set<string>();
        for (CampaignMemberStatus cms : [select label from CampaignMemberStatus 
        									where isDeleted = false and label != 'Sent' and label != 'Responded'
        									order by campaignId, sortorder limit 500]) {
   			if (!cmsSet.contains(cms.label)) {
   				allMemberStatuses.add(new SelectOption(cms.label, cms.label));
   				cmsSet.add(cms.label);
   			}
        }
	}
	
	public PageReference step2() {
		if (targetCampaignPicker.parentId != null) { 
			// load the selected campaign
			loadCampaign(targetCampaignPicker.parentId);
		} else {
			// validate - need either a parent or a new name
			if (newCampaignName == '') {
        		ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
        			'Please select a campaign or provide a new campaign name.'));
        		return null;
			} else {
				// create the new campaign
				targetCampaign.name = newCampaignName;
				try {
					insert targetCampaign;
					loadCampaign(targetCampaign.Id);
				} catch (exception e) {
		        	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));					
				}
			}
		}
		wizardStep = 2;
		batchJobCount = 0;
		done = false;
		ApexPages.getMessages().clear();
		return null;
	}	

	public PageReference clearPicker() {
		if (newCampaignName != null) targetCampaignPicker.parentId = null;
		return null;
	}

	public PageReference grabTargetCampaign() {
		loadCampaign(targetCampaignPicker.parentId);
		return null;
	}	

	public void loadCampaign(id cid) {
		// get the selected campaign
		campaign[] cq = [select id, name, startDate, endDate, parentId, ownerid, 
				type, status, isActive, numberOfContacts, unconverted_leads__c
				from campaign where id = : cid];
		if (!cq.isEmpty()) targetCampaign = cq[0];
	}

	public PageReference loadAddition() {
		// add selected campaign to list of campaigns to add
		if (campaignToAddPicker.parentId != null) {
			campaign[] cq = [select id, name, startDate, type, status, numberOfContacts, unconverted_leads__c
					from campaign where id = : campaignToAddPicker.parentId];
			if (!cq.isEmpty()) {
				campaignsToAdd.add(cq[0]);
				campaignToAddPicker.parentId = null;
			}
		}
		done = false;
		ApexPages.getMessages().clear();
		return null;
	}

	public PageReference loadSubtraction() {
		// if the last campaign in the list is selected, add a new one
		if (campaignToSubtractPicker.parentId != null) {
			campaign[] cq = [select id, name, startDate, type, status, numberOfContacts, unconverted_leads__c
					from campaign where id = : campaignToSubtractPicker.parentId];
			if (!cq.isEmpty()) {
				campaignsToSubtract.add(cq[0]);
				campaignToSubtractPicker.parentId = null;
			}
		}
		done = false;
		ApexPages.getMessages().clear();
		return null;
	}

	public PageReference clearAdds() {
		campaignsToAdd.clear();
		done = false;
		ApexPages.getMessages().clear();
		return null;
	}

	public PageReference clearSubtracts() {
		campaignsToSubtract.clear();
		done = false;
		ApexPages.getMessages().clear();
		return null;
	}

	// do the work
	public PageReference combine() {
		batchJobCount = 0;
		resultMessage = null;
		
		// load selected campaigns from all the lists - in case they aren't already loaded
		loadCampaign(targetCampaign.id);
		loadAddition();
		loadSubtraction();

		// make sure we have something to do
		if (campaignsToAdd.isEmpty() && campaignsToSubtract.isEmpty()) {
        	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
        		'Please select campaigns containing members you want to add to or exclude from the target campaign.'));
            return null;			
		}	

		// build a list of affected campaign ids for later batch processing		
		//string campaignIdList = '\'' + targetCampaign.Id + '\'';
		set<id> allCampaignIds = new set<id> { targetCampaign.id };

		// get the set of campaign ids for add and exclude
		addSet = new set<id>();
		subtractSet = new set<id>();
		for (campaign c : campaignsToAdd) {
			addSet.add(c.id);
	//		campaignIdList += ',\'' + c.Id + '\'';
			allCampaignIds.add(c.id);
		}
		for (campaign c : campaignsToSubtract) {
			subtractSet.add(c.id);
//			campaignIdList += ',\'' + c.Id + '\'';
			allCampaignIds.add(c.id);
		}
				
		// build the member status filter strings
		string addFilter = (addMemberStatus == null) ? '' :
			(addMemberStatus == 'AllResponded') ? 'and hasresponded = true ' :  
			(addMemberStatus == 'AllNotResponded') ? 'and hasresponded = false ' :  
			'and status = \'' + addMemberStatus + '\' ';  
		string excludeFilter = (excludeMemberStatus == null) ? '' :
			(excludeMemberStatus == 'AllResponded') ? 'and hasresponded = true ' :  
			(excludeMemberStatus == 'AllNotResponded') ? 'and hasresponded = false ' :  
			'and status = \'' + excludeMemberStatus + '\' '; 

		list<sobject> membersToAvoidC = new list<campaignMember>();
		list<sobject> membersToAvoidL = new list<campaignMember>();
		set<id> avoidSetC = new set<id>();
		set<id> avoidSetL = new set<id>();
		
		list<campaignMember> membersToRemove = new list<campaignMember>();
		list<campaignMember> membersToAdd = new list<campaignMember>();
			
		if (!subtractSet.isEmpty()) {
			if (intersectionForSubtracts) {
				// get ids of contacts and lead that are in all selected campaigns to exclude
				integer siz = subtractSet.size();
				membersToAvoidC = database.query(
					'select contactid from campaignmember where contactid != null ' +
					'and campaignid in : subtractSet ' + excludeFilter + 
					'group by contactid having count_distinct(campaignid) = : siz limit : BATCH_CUTOFF');

				membersToAvoidL = database.query(
					'select leadid from campaignmember where leadId != null and campaignid in : subtractSet ' +
					'and lead.isConverted = false ' + excludeFilter + 
					'group by leadid having count_distinct(campaignid) = : siz limit : BATCH_CUTOFF');
			} else {
				// get ids of contacts and lead that are in any of the selected campaigns to exclude
				membersToAvoidC = database.query(
					'select contactid from campaignmember where contactid != null ' +
					'and campaignid in : subtractSet ' + excludeFilter + 
					'group by contactid limit : BATCH_CUTOFF');

				membersToAvoidL = database.query(
					'select leadid from campaignmember where leadId != null and campaignid in : subtractSet ' + 
					'and lead.isConverted = false ' + excludeFilter + 
					'group by leadid limit : BATCH_CUTOFF');
			}
			// add the ids to sets
			for (sobject cm : membersToAvoidC) avoidSetC.add((id)(cm.get('contactId')));
			for (sobject cm : membersToAvoidL) avoidSetL.add((id)(cm.get('leadId')));
			
			// get members of the target campaign that we want to remove
			membersToRemove = [select id from campaignmember where campaignid = : targetCampaign.id 
									and (contactId in : avoidSetC or leadId in :avoidSetL) limit : BATCH_CUTOFF];
		}

		list<campaignMember> existingMembers = new list<campaignMember>();
		list<sobject> membersToAddC = new list<campaignMember>();
		list<sobject> membersToAddL = new list<campaignMember>();
		set<id> existingCons = new set<id>();
		set<id> existingLeads = new set<id>();
		
		if (!addSet.isEmpty()) {
			// get existing lead and contact ids from the target campaign, so we can avoid dupes
			existingMembers = [select id, contactid, leadId from campaignmember 
									where campaignid = : targetCampaign.id and
									(contactId != null or lead.isConverted = false) limit : BATCH_CUTOFF];

			for (campaignMember cm : existingMembers) {
				if (cm.contactId != null) existingCons.add(cm.contactId);
				if (cm.leadId != null) existingCons.add(cm.leadId);
			}

			if (intersectionForAdds) {
				// get ids of contacts and lead that are in all selected campaigns to add
				integer siz = addSet.size();
				
				membersToAddC = database.query(
					'select contactid from campaignmember where campaignid in : addSet and contactid != null ' + 
					'and contactid not in : existingCons and contactid not in : avoidSetC ' + addFilter + 
					'group by contactid having count_distinct(campaignid) = : siz limit : BATCH_CUTOFF');

				membersToAddL = database.query(
					'select leadid from campaignmember where campaignid in : addSet and leadId != null ' + 
					'and leadid not in : existingLeads and leadid not in : avoidSetL ' + addFilter +
					'and lead.isConverted = false ' + 
					'group by leadid having count_distinct(campaignid) = : siz limit : BATCH_CUTOFF');
			} else {
				// get ids of contacts and lead that are in any of the selected campaigns to add
				membersToAddC = database.query(
					'select contactid from campaignmember where contactid != null ' + 
					'and contactid not in : existingCons and contactid not in : avoidSetC ' + addFilter + 
					'and campaignid in : addSet group by contactid limit : BATCH_CUTOFF');
									
				membersToAddL = database.query(
					'select leadid from campaignmember where leadId != null ' + 
					'and leadid not in : existingLeads and leadid not in : avoidSetL ' + 
					'and lead.isConverted = false ' + addFilter +
					'and campaignid in : addSet group by leadid limit : BATCH_CUTOFF');
			}
				
			// create new member records to add to the target campaign
			for (sobject cm : membersToAddC) {
				// bail out if there are too many
				if (membersToAdd.size() == BATCH_CUTOFF) break;
				membersToAdd.add(
					new CampaignMember(
						campaignId = targetCampaign.Id,
						contactId = (id)(cm.get('contactId')),
						status = (newMemberStatus == null) ? defaultStatus : newMemberStatus
					)
				);
			}
			for (sobject cm : membersToAddL) {
				// bail out if there are too many
				if (membersToAdd.size() == BATCH_CUTOFF) break;
				membersToAdd.add(
					new CampaignMember(
						campaignId = targetCampaign.Id,
						leadId = (id)(cm.get('leadId')),
						status = (newMemberStatus == null) ? defaultStatus : newMemberStatus
					)
				);
			}
		}
							
		if (membersToAdd.isEmpty() && membersToRemove.isEmpty() && membersToAvoidC.size() < BATCH_CUTOFF && membersToAvoidL.size() < BATCH_CUTOFF) {
        	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
        		'The campaigns you selected do not contain any members to add or exclude.'));
            return null;			
		}	

		// bail out to batch mode if we have too many
		if (existingMembers.size() < BATCH_CUTOFF && membersToAdd.size() < BATCH_CUTOFF && membersToRemove.size() < BATCH_CUTOFF && 
				membersToAddC.size() < BATCH_CUTOFF && membersToAddL.size() < BATCH_CUTOFF && 
				membersToAvoidC.size() < BATCH_CUTOFF && membersToAvoidL.size() < BATCH_CUTOFF ) {

			// we can handle it without batch
			// add and remove campaign members in the target campaign
			try {
				resultMessage = '';
				
				if (!membersToAdd.isEmpty()) {
					insert membersToAdd;				
					membersAdded = membersToAdd.size();
					resultMessage += 'Added ' + membersAdded.format() + ' campaign member' + ((membersAdded==1) ? '. ' : 's. ');				
				}
				if (!membersToRemove.isEmpty()) {
					delete membersToRemove;
					membersRemoved = membersToRemove.size();
					resultMessage += 'Removed ' + membersRemoved.format() + ' campaign member' + ((membersRemoved==1) ? '.' : 's.');				
				}
				if (resultMessage == '') resultMessage = 'No members to add or remove.';
				
			} catch (exception e) {
				resultMessage = null;
			   	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
        			'Error: Unable to queue batch processing for campaign members. ' + e.getMessage()));
			}
			
			// refresh the campaign
			campaign[] cq = [select id, name, startDate, endDate, parentId, ownerid, 
					type, status, isActive, numberOfContacts, unconverted_leads__c
					from campaign where id = : targetCampaign.Id];
			if (!cq.isEmpty()) targetCampaign = cq[0];
					
		} else {
			// run this in batch apex			
			bcc = new GW_BATCH_CombineCampaigns();
			try {
				// first contacts
				bcc.query = 'SELECT id FROM contact WHERE id IN ' +
					'(select contactId from campaignMember where campaignId IN : allCampaignIds) '; 
				bcc.targetCampaign = targetCampaign.id;
				bcc.addSet = addSet; 
				bcc.subtractSet = subtractSet; 
				bcc.intersectionForAdds = intersectionForAdds;
				bcc.intersectionForSubtracts = intersectionForSubtracts;
				bcc.allCampaignIds = allCampaignIds;
				bcc.addFilter = addFilter;
				bcc.excludeFilter = excludeFilter;
				bcc.memberStatus = (newMemberStatus == null || newMemberStatus == '') ? defaultStatus : newMemberStatus;
				bcc.notifyEmail = NOTIFY_EMAIL;			
				batchProcessId = Database.executeBatch(bcc);

				// now leads
				bcc.query = 'SELECT id FROM lead WHERE isConverted = false and id IN ' +
					'(select leadId from campaignMember where campaignId IN :allCampaignIds) '; 
				batchProcessId = Database.executeBatch(bcc);
			} catch (exception e) {
			   	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
        			'Error: Unable to queue batch processing for campaign members. ' + e.getMessage()));
			}
		 		
 			// set up the results control to show either one or two batches
 			// if there are both leads and contacts to add remove, there will be two
 			if (membersToAddC.size() > 0 || (membersToRemove.size() > 0 && membersToAvoidC.size() > 0)) {
 				batchJobCount += 1;
 			}
 			if (membersToAddL.size() > 0 || (membersToRemove.size() > 0 && membersToAvoidL.size() > 0)) {
 				batchJobCount += 1;
 			}
 			// known issue: in the rare case that there are "exclude" campaigns that have both leads and contacts but we
 			// don't end up with two batches (because the target campaign doesn't have either those leads or those contacts),
 			// there will be two progress bars, but the second one won't work properly
 			
 			// set the batch message
 			batchLabel = 'Adding and Removing Campaign Members';
 			if (membersToAdd.size() == 0) batchLabel = 'Removing Campaign Members';
 			if (membersToRemove.size() == 0) batchLabel = 'Adding Campaign Members';
		}
		done = true;
		return null;
	}

    //if user cancels, go to campaign record or home if none
    public PageReference cancel() {
    	string thisId = (targetCampaign != null && targetCampaign.id != null) ? (string)targetCampaign.id : 
    		((targetCampaignPicker.parentId != null) ? (string)targetCampaignPicker.parentId : 'home/home.jsp' );
        PageReference oldPage = new PageReference('/' + thisId);
        oldPage.setRedirect(true);
        return oldPage;
    }

    public List<SelectOption> getMemberStatuses() {
        SelectOption[] options = new SelectOption[0];
        if (targetCampaign != null && targetCampaign.id != null) {
	   		options.add(new SelectOption('','- Select Status -'));
	        for (CampaignMemberStatus cms : [select id, Label, isDefault from CampaignMemberStatus 
	        									where CampaignId = : targetCampaign.id and isDeleted = false
	        									ORDER BY sortorder]) {
	   			options.add(new SelectOption(cms.label, cms.label));
	   			if (cms.isDefault) defaultStatus = cms.label; 
	        }
   			if (defaultStatus == null || defaultStatus == '') defaultStatus = options.size() > 0 ? 'Sent' : options[1].getLabel(); 
        } else {
	   		options.add(new SelectOption('Sent','Sent'));
	   		options.add(new SelectOption('Responded','Responded'));
	   		defaultStatus = 'Sent';
        }
        return options;
    }

	public static testMethod void testCampaignCombiner() {

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

		// create the page 
		PageReference pageRef=Page.CampaignCombiner; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('id', cmp0.id);
		
		// instantiate the controller
		GW_CTRL_CampaignCombiner controller=new GW_CTRL_CampaignCombiner();
		
		// click some stuff
		controller.clearPicker();
		controller.step2();
		controller.targetCampaign.name = 'TEST';
		controller.step2();
		controller.targetCampaignPicker.parentId = cmp0.id; 
		controller.grabTargetCampaign();
		List<SelectOption> lso = controller.getMemberStatuses();

		// click continue
		controller.step2(); 
		controller.combine();
	
		// pick some campaigns
		controller.campaignToAddPicker.parentId = cmp1.id;
		controller.loadAddition();
		controller.clearAdds();
		controller.campaignToAddPicker.parentId = cmp1.id;
		controller.loadAddition();
		controller.campaignToAddPicker.parentId = cmp2.id;
		controller.loadAddition();
		controller.campaignToSubtractPicker.parentId = cmp3.id;
		controller.loadSubtraction();
		controller.clearSubtracts();
		controller.campaignToSubtractPicker.parentId = cmp3.id;
		controller.loadSubtraction();
	
		// click calculate
		controller.combine();
		controller.cancel();
		
		// look for the data
		system.assertEquals(41, controller.membersAdded);
		system.assertEquals(3, controller.membersRemoved);
		system.assertEquals(42, controller.targetCampaign.numberOfContacts);
		system.assertEquals(1, controller.targetCampaign.unconverted_leads__c);
	}

	public static testMethod void testCampaignCombinerSpecifyStatus() {

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
		
		// add a few contacts to each campaign - some should overlap, and only 3 should be Responded
		campaignmember[] cms = new campaignmember[0];
		for (integer i = 0; i < 60; i++) {
			id cmpId = (i<5) ? cmp0.id : (i<30) ? cmp1.id : (i<40) ? cmp3.id : cmp2.id; 
			cms.add(new campaignmember(campaignId = cmpId, contactId = testCons[i].id, status=((i==45 || i==35 || i==25) ? 'Responded' : 'Sent')));
			if ((i>=50 && i<55) || i==0) cms.add(new campaignmember(campaignId = cmp1.Id, contactId = testCons[i].id));
			if ((i>=55 && i<60) || i<3) cms.add(new campaignmember(campaignId = cmp3.Id, contactId = testCons[i].id, status=((i==1) ? 'Responded' : 'Sent')));
		}
		cms.add(new campaignmember(campaignId = cmp1.Id, leadId = testLead.id));					
		insert cms;
		
		Test.startTest();

		// create the page 
		PageReference pageRef=Page.CampaignCombiner; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('id', cmp0.id);
		
		// instantiate the controller
		GW_CTRL_CampaignCombiner controller=new GW_CTRL_CampaignCombiner();
		
		// click some stuff
		controller.clearPicker();
		controller.step2();
		controller.targetCampaign.name = 'TEST';
		controller.step2();
		controller.targetCampaignPicker.parentId = cmp0.id; 
		controller.grabTargetCampaign();
		List<SelectOption> lso = controller.getMemberStatuses();

		// click continue
		controller.step2(); 
		controller.combine();
	
		// pick some campaigns
		controller.campaignToAddPicker.parentId = cmp1.id;
		controller.loadAddition();
		controller.campaignToAddPicker.parentId = cmp2.id;
		controller.loadAddition();
		controller.campaignToSubtractPicker.parentId = cmp3.id;
		controller.loadSubtraction();
		
		// set filters
		controller.addMemberStatus = 'Responded';
		controller.excludeMemberStatus = 'AllNotResponded';
	
		// click calculate
		controller.combine();
		controller.cancel();
		
		// look for the data
		system.assertEquals(2, controller.membersAdded);
		system.assertEquals(2, controller.membersRemoved);
		system.assertEquals(5, controller.targetCampaign.numberOfContacts);
		system.assertEquals(0, controller.targetCampaign.unconverted_leads__c);
	}

	public static testMethod void testCampaignCombinerIntersection() {

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

		// create the page 
		PageReference pageRef=Page.CampaignCombiner; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('id', cmp0.id);
		
		// instantiate the controller
		GW_CTRL_CampaignCombiner controller=new GW_CTRL_CampaignCombiner();
		
		// click some stuff
		controller.clearPicker();
		controller.step2();
		controller.targetCampaign.name = 'TEST';
		controller.step2();
		controller.targetCampaignPicker.parentId = cmp0.id; 
		controller.grabTargetCampaign();
		List<SelectOption> lso = controller.getMemberStatuses();

		// click continue
		controller.step2(); 
		controller.combine();
	
		// pick some campaigns
		controller.campaignToAddPicker.parentId = cmp1.id;
		controller.loadAddition();
		controller.clearAdds();
		controller.campaignToAddPicker.parentId = cmp1.id;
		controller.loadAddition();
		controller.campaignToAddPicker.parentId = cmp2.id;
		controller.loadAddition();
		controller.campaignToSubtractPicker.parentId = cmp3.id;
		controller.loadSubtraction();
		controller.clearSubtracts();
		controller.campaignToSubtractPicker.parentId = cmp3.id;
		controller.loadSubtraction();
	
		controller.intersectionForAdds = true;
		controller.intersectionForSubtracts = true;

		// click calculate
		controller.combine();
		controller.cancel();
		
		// look for the data
		system.assertEquals(5, controller.membersAdded);
		system.assertEquals(3, controller.membersRemoved);
		system.assertEquals(7, controller.targetCampaign.numberOfContacts);
	}

	public static testMethod void testCampaignCombinerBatch() {

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

		// create the page 
		PageReference pageRef=Page.CampaignCombiner; 
		Test.setCurrentPage(pageRef); 

		// set the parameter for the contact
		ApexPages.currentPage().getParameters().put('id', cmp0.id);
		
		// instantiate the controller
		GW_CTRL_CampaignCombiner controller=new GW_CTRL_CampaignCombiner();
		
		// click continue
		pagereference ref = controller.step2(); 
	
		// make sure we use batch apex
		controller.BATCH_CUTOFF = 5; 
	
		// pick some campaigns
		controller.campaignToAddPicker.parentId = cmp1.id;
		controller.loadAddition();
		controller.campaignToAddPicker.parentId = cmp2.id;
		controller.loadAddition();
		controller.campaignToSubtractPicker.parentId = cmp3.id;
		controller.loadSubtraction();
	
		// click calculate
		ref = controller.combine();
		system.assertEquals(2, controller.batchJobCount);
		
		Test.stopTest();
	}
}