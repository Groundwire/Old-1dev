public class ONEN_CTRL_CampaignToDrip {
// Written by Dave Manelski, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public Integer newMemberCount { get {return newMemberCount;} set {newMemberCount = value;} }
	public boolean actionPollerEnabled { get {return actionPollerEnabled;} set {actionPollerEnabled = value;} }
	public Campaign bogusCampaign { get {return bogusCampaign;} set {bogusCampaign = value;} }
	public Integer upcomingEmails { get {return upcomingEmails;} set {upcomingEmails = value;} }
	public boolean emailScheduled { get {return emailScheduled;} set {emailScheduled = value;} }
	Id campaignId;
	Public ONEN_DripCampaigns thisDripCampaign;
	
	//Create a map to hold a count for each drip event date upcoming in the next 30 days
	Map<Date,Integer> countMap = new Map<Date,Integer>();
	List<Drip_Event__c> upcomingEvents = new List<Drip_Event__c>();
	//public List<upcomingSendDate> upcomingSends { get {return upcomingSends;} set {upcomingSends = value;} }
    
    public ONEN_CTRL_CampaignToDrip(){
		//get campaign id
		campaignId = ApexPages.currentPage().getParameters().get('id');
		thisDripCampaign = new ONEN_DripCampaigns(campaignId);
		bogusCampaign  = new Campaign();
		newMemberCount = thisDripCampaign.countOfCampaignMembers.size();
    	//upcomingSends = new List<upcomingSendDate>();
    	actionPollerEnabled = false;
		
		/*
		//create a map of drip events coming up over the next 30 days
		upcomingEvents = [select Send_Date__c from Drip_Event__c where Send_Date__c <= :Date.today()+31 and Send_Date__c >= :Date.today() order by Send_Date__c ];
		if ( upcomingEvents.size() > 0 ) {
			emailScheduled = true;		
			for (Drip_Event__c event : upcomingEvents) {
				if ( countMap.get(event.Send_Date__c) == null ) {
					countMap.put(event.Send_Date__c, 1);
				} else {
					countMap.put(event.Send_Date__c, countMap.get(event.Send_Date__c)+1);
				}
			}
			
			//sort the send dates held in the map by date
			List<Date> dates = new List<Date>(countMap.keySet());
			dates.sort();
			
			//create a list of dates and sends per date (wrapper class) to display on the page
			//so that the end-user recognizes when the most email are scheduled over the next
			//30 days and avoids maxing out emails out of salesforce per day (2000 per day)
			for ( Date sendDate : dates ) {
				upcomingSendDate sd = new upcomingSendDate();
				sd.scheduledDateDay = sendDate.day();
				sd.scheduledDateMonth = sendDate.month();
				sd.scheduledDateYear = sendDate.year();
				sd.count = countMap.get(sendDate);
				upcomingSends.add(sd);
			}
			upcomingEmails = upcomingSends.size();
		} else {
			emailScheduled = false;
		}
		*/
	}
    /*
    //wrapper class to hold sends per date for the next 30 days
	public class upcomingSendDate {
		public integer count {get;set;}
		public integer scheduledDateDay {get;set;}
		public integer scheduledDateMonth {get;set;}
		public integer scheduledDateYear {get;set;}
	}
    */
    private Integer getCount() {
	    Integer i = [select count() from CampaignMember where CampaignId = :campaignId and Status = 'New' limit 9999];
	    
	    return i;
    }
    
    public void addNewCampaignMembersToDrip() {
		
		actionPollerEnabled = true;
		
	}
    
    Integer numberProcessed = 0;
    
    String EndProcess = 'Process is starting soon... do not change page';
    decimal PercentDone = 0;
    
    public PageReference incrementCounter() {
    	if ( newMemberCount == null ) { newMemberCount = getCount(); }
    	
    	thisDripCampaign.bogusCampaign=bogusCampaign;
    	
    	Integer countOfContacts = [Select count() from CampaignMember where status='New' and CampaignId = :campaignId LIMIT 10];
    	  	
        if ( numberProcessed < newMemberCount ) { 
        	
            if (thisDripCampaign.addContactsToDrip()) {
				PageReference campaignPage = new PageReference('/' + campaignId);
		        campaignPage.setRedirect(true);
		        return campaignPage;
			} else {
				//need message
			return null;	
			}
                   
            numberProcessed = numberProcessed + countOfContacts; 
            PercentDone = (numberProcessed*100) / newMemberCount;
            EndProcess = 'Processing... Do not change page - Records Processed: '+numberProcessed+' ( '+PercentDone+'% done )'; 
        } else {
            EndProcess = ' PROCESS COMPLETED... All Campaign Members added to the drip campaign and assigned upcoming send dates';    
        }    
        
    
    return null;
    }
    
    public String getEndProcess() {
        return EndProcess;
    }
	
	
	/* TESTS */
	
	
    static testMethod void testAddToDrip() {
		
		//create an campaign that does not trip the trigger
		Campaign thisCampaign = new Campaign (
			Name='Test_Campaign',
			IsActive=true
			);
		insert thisCampaign;
		
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
		
		//insert the statuses so they exist in the test and don't need to be created
		//before deployment or installation of the package
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
		
		//create new statuses before deleting the old values
		if ( newStatuses.size() > 0 ) {
			insert newStatuses;	
		}
		
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.campaignToDrip'));
		
		//create an campaign
		Campaign dripCampaign = new Campaign (
			Name='Test_Drip',
			Type='Drip Campaign',
			IsActive=true
			);
		
		insert dripCampaign; 

		Drip_Step__c[] dripSteps = new Drip_Step__c[0];
		
		Integer dripStepInterval = 2;
		String dripStepIntervalUnit = 'Week(s)';
		
		for(Integer dripStepCounter=1;dripStepCounter<6;dripStepCounter++) {
			//create the drip steps
			Drip_Step__c dripStep = new Drip_Step__c (
				Email_Template__c = 'bogus_template',
				Interval_Unit__c = (dripStepInterval*dripStepCounter)-dripStepInterval,
				Interval_Type__c = dripStepIntervalUnit,
				Campaign__c = dripcampaign.id
				);
			
			dripSteps.add( dripStep );
		}
		insert dripSteps;
		
		system.AssertEquals(5,[select count() from Drip_Step__c where Campaign__c = :dripcampaign.id]);
    	
    	Contact[] contactsForDripCampaign = new Contact[0];
		
		for(Integer contactCounter=1;contactCounter<6;contactCounter++) {
			//create the drip steps
			Contact thisContact = new Contact (
				LastName='Smith '+contactCounter,
				Email='Smith@test.com'
				);
			
			contactsForDripCampaign.add( thisContact );
		}
		insert contactsForDripCampaign;
		
		CampaignMember[] CampaignMembersForDripCampaign = new CampaignMember[0];
		
		for(Integer CampaignMemberCounter=1;CampaignMemberCounter<6;CampaignMemberCounter++) {
			//create the drip steps
			CampaignMember thisCampaignMember = new CampaignMember (
				ContactId = contactsForDripCampaign[CampaignMemberCounter-1].Id,
				CampaignId = dripCampaign.id,
				Status='New'
				);
			
			CampaignMembersForDripCampaign.add( thisCampaignMember );
		}
		system.debug('campaign member list for inserting: ' + CampaignMembersForDripCampaign);
		insert CampaignMembersForDripCampaign;
    	
    	List<CampaignMember> newCampaignMembers = [select id from CampaignMember where CampaignId = :dripCampaign.id and status='New'];
		system.AssertEquals(5,newCampaignMembers.size());
				 
		//get the created opp Id
		ApexPages.currentPage().getParameters().put('id', dripCampaign.id);
		//instantiate the controller for this opp
		ONEN_CTRL_CampaignToDrip controller = new ONEN_CTRL_CampaignToDrip();
		
		system.AssertEquals(dripCampaign.id,controller.campaignId);	
		system.AssertEquals(5,controller.newMemberCount);
		system.AssertEquals(5,controller.getCount());
		
		controller.bogusCampaign.NumberSent = 5;
		controller.bogusCampaign.StartDate = system.today();
		//controller.newMemberCount = 5;
		//system.assertNotEquals(null,controller.addNewCampaignMembersToDrip());

		controller.addNewCampaignMembersToDrip();
		system.assertEquals(true,controller.actionPollerEnabled);
		controller.incrementCounter();
		//query for steps
		Drip_Event__c[] createdDripEvents = [select Id,Contact__c,Campaign__c,Active__c from Drip_Event__c where Campaign__c=:dripCampaign.id];
		system.debug('New drip Events: ' + createdDripEvents);
		system.assertEquals(25,createdDripEvents.size());
		
		Drip_Event__c[] createdDripEventsForContact1 = [select Id,Contact__c,Campaign__c,Email_Template__c,Send_Date__c,Active__c from Drip_Event__c where Campaign__c=:dripCampaign.id and Contact__c = :contactsForDripCampaign[0].id ORDER BY Send_Date__c];
		system.assertEquals(5,createdDripEventsForContact1.size());
		system.assertEquals(system.Today(),createdDripEventsForContact1[0].Send_Date__c);
		system.assertEquals(system.Today().addDays(14),createdDripEventsForContact1[1].Send_Date__c);
		system.assertEquals(system.Today().addDays(28),createdDripEventsForContact1[2].Send_Date__c);
		system.assertEquals(system.Today().addDays(42),createdDripEventsForContact1[3].Send_Date__c);
		system.assertEquals(system.Today().addDays(56),createdDripEventsForContact1[4].Send_Date__c);
		system.assertEquals(true,createdDripEventsForContact1[0].Active__c);
		system.assertEquals(true,createdDripEventsForContact1[1].Active__c);
		system.assertEquals(true,createdDripEventsForContact1[2].Active__c);
		system.assertEquals(true,createdDripEventsForContact1[3].Active__c);
		system.assertEquals(true,createdDripEventsForContact1[4].Active__c);
		
		controller.getEndProcess();
    	system.debug(controller.endProcess);
		
		ONEN_CTRL_CampaignToDrip controller2 = new ONEN_CTRL_CampaignToDrip();
		//system.assertEquals(true,controller2.emailScheduled);
    	
    }

}