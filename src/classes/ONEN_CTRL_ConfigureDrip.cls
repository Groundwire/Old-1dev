public class ONEN_CTRL_ConfigureDrip {
// Written by Dave Manelski, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	//class that does much of heavy lifting
	public ONEN_DripCampaigns thisDripCampaign;
	//controls the display of the bottom half of the page
	public Boolean renderSteps { get {return renderSteps;} set {renderSteps = value;} }
	//the campaign we're coming from
	Id campaignId;
	Campaign thisCampaign;
	//list for available email templates
	public List<SelectOption> emailTemplateOptions = new List<SelectOption>();
    //newly created steps
	public List<Drip_Step__c> newDripSteps;
	//boolean to warn of existing drip steps on this campaign
	public Boolean existingSteps { get { return existingSteps; } set { existingSteps = value; } }
	
	public Boolean startToday { get { return startToday; } set { startToday = value; thisDripCampaign.startToday = value; } }

	public Boolean successfulAdd { get {return successfulAdd;} set {successfulAdd = value;} }
	
	public ONEN_CTRL_ConfigureDrip(){
		//get campaign id
		campaignId = ApexPages.currentPage().getParameters().get('id');
		renderSteps = false; 
		thisDripCampaign = new ONEN_DripCampaigns(campaignId); 
		thisCampaign = [select Number_of_Drip_Steps__c from Campaign where id = :campaignId];
		//determine if there are existing drip steps and throw a warning to the user on the VF page
		if (thisCampaign.Number_of_Drip_Steps__c > 0) {
			existingSteps = true;
		} else {
			existingSteps = false;
		}
		
		//get the list of available templates and create the select options
		EmailTemplate[] templates = [Select Name, DeveloperName From EmailTemplate where Folder.Name = 'Drip Email Templates' order by name];
        if (templates.size()>0) {
        	emailTemplateOptions.add(new SelectOption('','- select a template -'));
        	for (EmailTemplate thisTemplate : templates){
		        emailTemplateOptions.add(new SelectOption(thisTemplate.DeveloperName,thisTemplate.Name)); 
        	}
        }
	}
	
	public void showSteps() {
		renderSteps = true;
	}
	
	public List<SelectOption> getEmailTemplates() {
        return emailTemplateOptions;
    }
	
	public List<SelectOption> getItems() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('1','1'));
        options.add(new SelectOption('2','2'));
        options.add(new SelectOption('3','3'));
        options.add(new SelectOption('4','4'));
        options.add(new SelectOption('5','5'));
        options.add(new SelectOption('6','6'));
        options.add(new SelectOption('7','7'));
        options.add(new SelectOption('8','8'));
        options.add(new SelectOption('9','9'));
        options.add(new SelectOption('10','10'));
        options.add(new SelectOption('11','11'));
        options.add(new SelectOption('12','12'));
        options.add(new SelectOption('13','13'));
        options.add(new SelectOption('14','14'));
        options.add(new SelectOption('15','15'));
        options.add(new SelectOption('16','16'));
        options.add(new SelectOption('17','17'));
        options.add(new SelectOption('18','18'));
        options.add(new SelectOption('19','19'));
        options.add(new SelectOption('20','20'));
        options.add(new SelectOption('21','21'));
        options.add(new SelectOption('22','22'));
        options.add(new SelectOption('23','23'));
        options.add(new SelectOption('24','24'));       
        return options;
    } 
    
    //integer for the number of drip events to create
    public Integer numberOfDripEvents { get {return numberOfDripEvents;} set {numberOfDripEvents = value; thisDripCampaign.dripStepCount = value;} } 
    
    //integer to hold the interval chosen
    public Integer interval { get {return interval;} set {interval = value; thisDripCampaign.dripStepInterval = value;} }   
    
    public List<SelectOption> getIntervals() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('1','1'));
        options.add(new SelectOption('2','2'));
        options.add(new SelectOption('3','3'));
        options.add(new SelectOption('4','4'));
        options.add(new SelectOption('5','5'));
        options.add(new SelectOption('6','6'));
        options.add(new SelectOption('7','7'));
        options.add(new SelectOption('8','8'));
        options.add(new SelectOption('9','9'));
        options.add(new SelectOption('10','10'));
        options.add(new SelectOption('11','11'));
        options.add(new SelectOption('12','12'));
        return options;
    }
    
    //the unit of the interval
    public String intervalUnit { get {return intervalUnit;} set {intervalUnit = value; thisDripCampaign.dripStepIntervalUnit = value;} }
    
    public List<SelectOption> getIntervalUnits() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('Week(s)','Week(s)'));
        options.add(new SelectOption('Month(s)','Month(s)'));
        options.add(new SelectOption('Year(s)','Year(s)'));
        return options;
    }	
    
    //list to hold new drip steps
    //private List<Drip_Step__c> tempDripSteps = new List<Drip_Step__c>();
    
    public List<Drip_Step__c> getDripSteps() {
    
	   	if ( thisDripCampaign.dripStepsToCreate() ) {
    		newDripSteps = thisDripCampaign.stepsToCreate;
	   	} 
    	return newDripSteps;
    }
    

	public PageReference createNewDripSteps() {
		
		if ( thisDripCampaign.createDripSteps() ) {
			PageReference campaignPage = new PageReference('/' + campaignId);
	        campaignPage .setRedirect(true);
	        return campaignPage;
		} else {
			//need message
		return null;	
		}
		
	}   
    
    //test the trigger that inserts campaign member statuses
    static testmethod void TestInsertStatusesTrigger () {
		
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
		
		//now create a drip campaign
		Campaign dripCampaign = new Campaign (
			Name='Test Drip',
			Type='Drip Campaign',
			IsActive=true
			);
		
		insert dripCampaign;		
		
		// Verify that the new Campaign Member Status 'New' has been created
		CampaignMemberStatus newStatusOne = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :dripCampaign.id and Label = 'New' limit 1];
		System.assertEquals('New', newStatusOne.Label);
		
		// Verify that the new Campaign Member Status 'In Progress' has been created
		CampaignMemberStatus newStatusTwo = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :dripCampaign.id and Label = 'In Progress' limit 1];
		System.assertEquals('In Progress', newStatusTwo.Label);
		
		// Verify that the new Campaign Member Status 'Completed' has been created
		CampaignMemberStatus newStatusThree = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :dripCampaign.id and Label = 'Completed' limit 1];
		System.assertEquals('Completed', newStatusThree.Label);
    }	
	   
	static testmethod void TestConfigureDrip () {
		
		//create an campaign that does not trip the member statuses trigger
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
		Test.setCurrentPageReference(new PageReference('Page.configureDrip'));
		
		//create an campaign
		Campaign dripCampaign = new Campaign (
			Name='Test Drip',
			Type='Drip Campaign',
			IsActive=true
			);
		
		insert dripCampaign;		
		
		//get the created opp Id
		ApexPages.currentPage().getParameters().put('id', dripCampaign.id);
		//instantiate the controller for this opp
		ONEN_CTRL_configureDrip controller = new ONEN_CTRL_configureDrip();
		
		//set the interval unit	
		String unit = 'Week(s)';	
		controller.intervalUnit = unit;
		system.AssertEquals(unit,controller.intervalUnit);
		
		//set the number of drip events
		Integer stepCount = 4;
		controller.numberOfDripEvents = stepCount;
		system.AssertEquals(stepCount,controller.numberOfDripEvents);
		
		//set the interval
		Integer intervalCount = 2;
		controller.interval = intervalCount;
		system.AssertEquals(intervalCount,controller.interval);
		
		//set the boolean for start immediately
		Boolean startImmediately = true;
		controller.startToday = startImmediately;
		system.AssertEquals(startImmediately,controller.startToday);
		
		//a list for the new steps
		//List<Drip_Step__c> newSteps = new List<Drip_Step__c>();
		//create the new steps objects
		controller.showSteps();
		system.AssertEquals(4,controller.getDripSteps().size());
		system.AssertEquals(24,controller.getItems().size());
		system.AssertEquals(12,controller.getIntervals().size());
		system.AssertEquals(3,controller.getIntervalUnits().size());
		
		//set the templates
		String templateName = 'bogus_template';
		controller.newDripSteps[0].Email_Template__c = templateName;
		controller.newDripSteps[1].Email_Template__c = templateName;
		controller.newDripSteps[2].Email_Template__c = templateName;
		controller.newDripSteps[3].Email_Template__c = templateName;
		
		//create the drip steps
		controller.createNewDripSteps();
		
		List<Drip_Step__c> newSteps = [select Id, Campaign__c, Email_Template__c, Interval_Unit__c, Interval_Type__c from Drip_Step__c where Campaign__c = :dripCampaign.id];
		
		system.AssertEquals(4,newSteps.size());
		
		Drip_Step__c newStep = [select Id, Campaign__c, Email_Template__c, Interval_Unit__c, Interval_Type__c from Drip_Step__c where Campaign__c = :dripCampaign.id and Email_Template__c = :templateName LIMIT 1];
		
		system.AssertEquals(templateName,newStep.Email_Template__c);
		system.AssertEquals(0,newStep.Interval_Unit__c);
		system.AssertEquals('Week(s)',newStep.Interval_Type__c);
		
		dripCampaign.IsActive = false;
		update dripCampaign;
		
	} 

}