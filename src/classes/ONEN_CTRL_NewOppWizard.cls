public virtual class ONEN_CTRL_NewOppWizard {
// Written by Steve Andersen, copyright (c) 2008 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	//object to hold opportunity
	public Opportunity opportunity = new Opportunity();

	//we instantiate this dummy object to get the Contact lookup field. we never submit the object, just use it for it's picker
	public OpportunityContactRole contactRole { get {return contactRole;} set {contactRole = value;} }
	
	//create this bogus opportunity to capture a few variables (date fields, etc.)
	//for use in the controller but will never get saved
	public Opportunity bogusOpp {get {return bogusOpp;} set {bogusOpp = value;} }
	
	//boolean to indicate whether or not the first monthly gift is received or not
	public Boolean paymentReceived {get {return paymentReceived;} set {paymentReceived = value;} }
	
	//primary Contact & Account
	Contact primaryContact = new Contact();
	Account primaryOrg = new Account();
	id primaryContactId;
	id primaryAccountId;
	
	public Id oppRecordTypeId { get {return oppRecordTypeId;} set {oppRecordTypeId = value;} }
	public List<RecordType> recordTypeList {get{return recordTypeList;}set{recordTypeList=value;}}
	
	public String errorMessageText {get{return errorMessageText;}set{errorMessageText=value;}}
	String errorMessageIndividualOrgForOrgOpp = 'You cannot create Organizational gifts for the Individual Organization. Create a gift for the Contact or create an Organizational gift for a different Organization.';
	String errorMessageNoOrgForOrgOpp = 'You must select an Organization for gifts that are applied to an Organization.';
	String errorMessageNoContactForContactOpp = 'You must select a Contact for gifts that are applied to a Contact.';
	
	//instantiate the class
	ONEN_OpportunityMaintenance newOpp = new ONEN_OpportunityMaintenance(null);
	//list to hold open opps
	public List<Opportunity> openOppList {get{return openOppList;}set{openOppList=value;}}
	
	//SelectOptions for the record type picklist
	public List<SelectOption> recordTypeNameList {get{return recordTypeNameList;}set{recordTypeNameList = value;}}
	
	//string to hold the current page URL
	string currentPageURL;
	
	public integer FYstartMonth = 1;
	private integer nbrInstallments;
	
    private OppRollupSettings__c oppSettings;
	
	//constructor
	public ONEN_CTRL_NewOppWizard (ApexPages.StandardController controller) {

		oppSettings = OppRollupSettings__c.getInstance();

		//get record from standard controller
        this.opportunity = (Opportunity)controller.getRecord();
    
        //instantiate dummy object for Contact lookup
        contactRole = new OpportunityContactRole();

		//create the empty list for opps
		openOppList = new List<Opportunity>();
		
		//instatiate the bogus opp so that we can use the Close Date field for monthly payments
		//this opp will never get saved or written to the database
		bogusOpp = new Opportunity();
		bogusOpp.CloseDate = opportunity.CloseDate!=null ? opportunity.CloseDate : Date.today();

        // newOpp = new ONEN_OpportunityMaintenance(null);  // redundant
		//grab the id of the account and the contact
		newOpp.primaryAccountId = opportunity.AccountId;
		newOpp.primaryContactId = contactRole.ContactId;
		
		primaryContactId = contactRole.ContactId;
		primaryAccountId = opportunity.AccountId;
		
		//default monthly gift payment received to checked
		paymentReceived = TRUE;
    
        setOppDefaults();

        //check for open opps for this donor
        // getOpenOpps();

		setRecordTypes (); 		
	}
		
	protected virtual void setOppDefaults () {
		// called by constructor on load
		
	    //get the vars from the querystring
        opportunity.AccountId = ApexPages.currentPage().getParameters().get('accid');
        opportunity.CampaignId = ApexPages.currentPage().getParameters().get('campid');
        contactRole.ContactId = ApexPages.currentPage().getParameters().get('conid');
	
		//make the CloseDate Today
        opportunity.CloseDate = system.Today();
        
        //if we have a contactId from the querystring, or don't have an accid, then assume it's a Contact Opp
        if(ApexPages.currentPage().getParameters().get('conid')!=null||ApexPages.currentPage().getParameters().get('accid')==null) {
        	oppApplicant = 'Contact';        	 
    	} else {
        	oppApplicant = 'Organization';
        }
	}
	
	public  virtual void setRecordTypes () {
        //get the list of acceptable recordTypes
        resetRecordTypeArray();
		oppRecordTypeId =  GW_RecTypes.GetRecordTypeId('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);	
		errorMessageText = null;
	}
	
	//string from radio selector
	public String oppApplicant { get {return oppApplicant;}
		set {
			errorMessageText=null;
			oppApplicant = value;
			
			getOpenOpps(); 
			}
		}
	
	//get open opps for this donor
	public virtual void getOpenOpps(){
		if (oppApplicant=='Contact'){
			//get the latest ContactId
			newOpp.primaryContactId = contactRole.ContactId;
			//get the openopps list for this contact
			openOppList = newOpp.getContactOpenOpps();
		} else {
			//get the latest accountid
			newOpp.primaryAccountId = opportunity.AccountId;
			//get the openopps list for this account
			openOppList = newOpp.getAccountOpenOpps();
		}	
	}
	
	
	//get a list of acceptable record types
	public virtual void resetRecordTypeArray() {
		//blank out the list for the select options
		recordTypeNameList = new List<SelectOption>();
	 	
	 	Map<String, Id> rtidMap = GW_RecTypes.GetRecordTypeIdMap('Opportunity');
	 	
		// find out which opp record types to exclude.
		set<string> opprtExcludeContact = new set<string>();
		set<string> opprtExcludeOrg = new set<string>();	 	

		if (oppSettings != null) {
			if (oppSettings.Opp_Rectypes_Excluded_New_Opp_Contact__c != null) {
				opprtExcludeContact = new set<string>(oppSettings.Opp_Rectypes_Excluded_New_Opp_Contact__c.split(';'));
			}
			if (oppSettings.Opp_Rectypes_Excluded_New_Opp_Org__c != null) {
				opprtExcludeOrg = new set<string>(oppSettings.Opp_Rectypes_Excluded_New_Opp_Org__c.split(';'));
			}
		}
		
		//loop through the record types for Opportunity
		for ( string thisRecordType : rtidMap.keySet()) {
			//if we're creating a Contact Opp, get all the right record types
        	if(oppApplicant == 'Contact') {
        		if (!opprtExcludeContact.contains(thisRecordType)) {
        			recordTypeNameList.add(new SelectOption(rtidMap.get(thisRecordType),thisRecordType));
        		}
        	//if we're creating an Organization Opp, get all the right record types
        	} else {
        		if (!opprtExcludeOrg.contains(thisRecordType)) {
        			recordTypeNameList.add(new SelectOption(rtidMap.get(thisRecordType),thisRecordType));
        		}
        	}
        }
	}

	
	//save the opportunity
	public virtual PageReference save() {

		newOpp.primaryAccountId = opportunity.AccountId;
		newOpp.primaryContactId = contactRole.ContactId;
		opportunity.RecordTypeId = oppRecordTypeId;
	
		//if we've got a Contact id on our dummy object, get the contact, put the id on the Opp
		// so conrole will be created by trigger
		if (contactRole.ContactId!=null) {
			primaryContact = newOpp.getPrimaryContact();
			opportunity.CR_Contact_Id__c = contactRole.ContactId;
			//DJH: inherit the contact's anonymous setting
			opportunity.Anonymous__c = primaryContact.Anonymous__c;			
		}

		//if the Account Id isn't null, get the Account and put the Id on the Opp
		// note: the value returned here isn't used anywhere in this controller (method should be void)
		// but this is necessary b/c the value in the OppMaintenance class is used later
		if (opportunity.AccountId!=null) {
			primaryOrg = newOpp.getPrimaryAccount();
		}

		if ( saveErrorCheck() == true) {
			return null;
		} else {
			//if we've selected a Contact, null out the org on the opp & set role & soft credit
			if (oppApplicant=='Contact') {
				opportunity.AccountId=null;
			    opportunity.CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(GW_RecTypes.getRecordTypeName('Opportunity',oppRecordTypeId));
			    opportunity.CR_HHroles__c = true;
			    opportunity.ContactId__c = contactRole.ContactId;
	        } else {
				// if org, set role etc accordingly
			    opportunity.CR_Contact_Role__c = ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE;
			    opportunity.CR_HHroles__c = false;
			    opportunity.ContactId__c = null;
	        }

		 	//if the closedate is null, pick today
		 	//  TBD do we really want this?  or simply make close date required?? - MS 6/09	
			if (opportunity.CloseDate==null) {
				opportunity.CloseDate=system.Today(); 
			}

			// write opp name & stage 
			newOpp.newOpp = opportunity;
			opportunity.Name = newOpp.oppName(oppApplicant,false);
			
			//set the stage, amount, Membership Dates, etc. based on whether or not this is a monthly gift
			if (opportunity.Monthly_Gift__c) {
				
				integer firstPaymentMonth = (bogusOpp.closeDate != null) ? bogusOpp.closeDate.month() : system.today().month();
				
				// first, if monthly, figure out fiscal year, but for tests anticipate that test will set it manually
				if (FYstartMonth==1 && !test.isRunningTest() && oppSettings.New_Monthly_Gifts_Use_Fiscal_Year__c==true) {
					organization o = [select fiscalYearStartMonth from organization limit 1];
					FYstartMonth = o.fiscalYearStartMonth;
				}
				if (FYstartMonth > 1 ) {

					// matthew's plan
					//integer firstPaymentMonth = system.today().month();
					
					// evan and dh's plan
					if (firstPaymentMonth < FYstartMonth) {
						nbrInstallments = FYstartMonth - firstPaymentMonth; 
					} else if (firstPaymentMonth > FYstartMonth) {
						nbrInstallments = 12 - (firstPaymentMonth - FYstartMonth);
					} 
				} else {
					nbrInstallments = 13 - firstPaymentMonth;
				}
				opportunity.StageName = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE;
				opportunity.Amount = nbrInstallments * opportunity.Monthly_Gift_Amount__c;
				opportunity.Name = opportunity.Name.replace(GW_RecTypes.GetRecordTypeName('Opportunity', oppRecordTypeId),'Monthly Gift');
			} else {
				opportunity.StageName = ONEN_Constants.OPP_DEFAULT_STAGE;
			}
			
			CustomOppProcessing ();
			
			insert opportunity;
			
			monthlyGiftProcessInstallments();
			
			//redirect to newly created opp in edit mode
			PageReference newOppDetail = new PageReference('/' + opportunity.id +'/e?retURL=/' + opportunity.id);
	        newOppDetail.setRedirect(true);
	        return newOppDetail;
		}
	}

	
	protected virtual boolean saveErrorCheck () {
		//if this is an org gift for the individual account, flag that as a problem
		if (oppApplicant=='Organization'&&newOpp.isIndividualAccount) {
			errorMessageText = errorMessageIndividualOrgForOrgOpp;
			return true;	
		} else if (oppApplicant=='Organization'&&opportunity.AccountId==null) {
			errorMessageText = errorMessageNoOrgForOrgOpp;
			return true;
		} else if (oppApplicant=='Contact'&&opportunity.CR_Contact_Id__c==null) {
			errorMessageText = errorMessageNoContactForContactOpp;
			return true;
		} else {
			return false;
		}
		
	}

	protected virtual void CustomOppProcessing () {
		// override w/ custom code
		// this is run just before opp insert
	}

	protected virtual void monthlyGiftProcessInstallments () {
		
		if (opportunity.Monthly_Gift__c) {
			
			//integer to hold how many months are left in the year from the time of this gift
			//for calculation of an amount on an opportunity that is a monthly gift
			// Integer monthsLeftInYearIncludingThisOne = 13-bogusOpp.CloseDate.month();
			
			//create a list to hold the payment schedule for the rest of the year
			List<OppPayment__c> paymentSchedule = new List<OppPayment__c>();
			
			OppPayment__c firstPayment = new OppPayment__c(
				Amount__c = opportunity.Monthly_Gift_Amount__c,
				Date__c = bogusOpp.CloseDate,
				IsInstallment__c = True,
				Opportunity__c = opportunity.id,
				Opp_For_Installment__c = opportunity.id,
				Paid__c = paymentReceived
			);
			paymentSchedule.add(firstPayment);
			for (integer i=1; i < nbrInstallments; i++) {
				OppPayment__c payment = new OppPayment__c (
				Amount__c = opportunity.Monthly_Gift_Amount__c,
				Date__c = bogusOpp.CloseDate.addMonths(i),
				IsInstallment__c = True,
				Opportunity__c = opportunity.id,
				Opp_For_Installment__c = opportunity.id,
				Paid__c = false
				);
				paymentSchedule.add(payment);
			}
			
			if (paymentSchedule.size()>0) {
				insert paymentSchedule;
				
				//delete the automatically created mirror payment
				List<OppPayment__c> mirrorOppPaymentsToDelete = new List<OppPayment__c>();  
				
		    	mirrorOppPaymentsToDelete = [Select Id from OppPayment__c where IsInstallment__c=false and Opportunity__c=:opportunity.id];
		    	
		        if(mirrorOppPaymentsToDelete.size()>0){
		        	delete mirrorOppPaymentsToDelete;
		        }		
			}
		}
		
		
	}


	static testmethod void testContactOpp () {		
		
		//create an opportunity
		Opportunity theOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)		
		);
		
		//create an Contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName = 'Smith'		
		);
		insert firstContact;
		
		//create an Contact
		Contact secondContact = new Contact (
			FirstName='Albert',
			LastName = 'Moyo'		
		);
		insert secondContact;
		
		//create an opp for this contact
		//create an opportunity
		Opportunity secondContactOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name = 'Test second contact opp',
			amount=100,
			StageName='Prospecting',
			CloseDate = system.Today(),
			CR_Contact_Id__c = secondContact.id,
			CR_Contact_Role__c = 'Individual Donor'
		);
		
		insert secondContactOpp;
		
		//create an Account
		Account firstAccount = new Account (
			Name='XYZ Org'		
		);
		insert firstAccount;
		
		//create an opportunity
		Opportunity firstAccountOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name = 'Test first account opp',
			amount=100,
			AccountId=firstAccount.Id,
			StageName='Prospecting',
			CloseDate = system.Today()
		);
		
		insert firstAccountOpp;
		
		//create an opportunity
		Opportunity firstAccountOpp1 = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name = 'Test first account opp',
			amount=100,
			AccountId=firstAccount.Id,
			StageName='Prospecting',
			CloseDate = system.Today()
		);
		
		insert firstAccountOpp1;
		
		//create two opps for this account
		
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
		//put the contact and account id on the page
		ApexPages.currentPage().getParameters().put('conid', firstContact.id);
		ApexPages.currentPage().getParameters().put('accid', firstAccount.id);
		
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
		//pass the controller into the extension
		ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
		//since we have a contact id, we should be in contact mode		
		system.AssertEquals('Contact',ext.OppApplicant);
		//should show no gifts for this contact
		system.AssertEquals(0,ext.openOppList.size());
		//change to second contact
		ext.contactRole.ContactId = secondContact.Id;
		//get the open opps
		ext.getOpenOpps();
		//should be one gift for this contact
		system.AssertEquals(1,ext.openOppList.size());
		//switch to Organization gifts
		ext.OppApplicant='Account';
		//change to Account
		ext.opportunity.AccountId = firstAccount.Id;
		//get opps
		ext.getOpenOpps();
		//should be two gifts for this account
		system.AssertEquals(2,ext.openOppList.size());
		//change to second contact
		ext.contactRole.ContactId = secondContact.Id;
		//get the open opps
		ext.getOpenOpps();
		//should be two gifts for this account because we didn't change applicant
		system.AssertEquals(2,ext.openOppList.size());
		//switch to Contact gifts
		ext.OppApplicant='Contact';
		//get the open opps
		ext.getOpenOpps();
		//should be one gift for this contact
		system.AssertEquals(1,ext.openOppList.size());
		
		
		
		/*left to test
			1. org gift - DONE
			2. record type exclusion lists
			3. contact and account selection boxes = DONE
			4. campaign id - DONE
			5. opplist as the primary contact and account changes - DONE	
		*/
		
	}
	
	static testmethod void testOrgOpp () {	
		
		//create an opportunity
		Opportunity theOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
		);
		
		//create an Contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName = 'Smith'		
		);
		insert firstContact;
		
		//create an Campaign
		Campaign firstCampaign = new Campaign (
			Name = 'Test Campaign'		
		);
		insert firstCampaign;
		
		//create an Account
		Account firstAccount = new Account (
			Name='XYZ Org'		
		);
		insert firstAccount;
		
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
		//put the contact and account id on the page
		ApexPages.currentPage().getParameters().put('conid', firstContact.id);
		ApexPages.currentPage().getParameters().put('accid', firstAccount.id);
		ApexPages.currentPage().getParameters().put('campid', firstCampaign.id);
		
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
		//pass the controller into the extension
		ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
		//since we have a contact id, we should be in contact mode	
		ext.OppApplicant = 'Organization';	
		system.AssertEquals('Organization',ext.OppApplicant);
		//get a rt id
			// MS mod 10/9/08: use Rectype class to avoid hardcoding rectype name
		//RecordType giftRT = [Select Id from RecordType where SObjectType='Opportunity' and Name='Gift' limit 1];
		/*
		ONEN_RecordTypes rtlookup = new ONEN_RecordTypes ('Opportunity');
		*/
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		
		
		ext.oppRecordTypeId = rtid;
		//next step
		//ext.step2();
		//eet a valid close date
		//ext.opportunity.CloseDate = system.Today();
		//dave
		String savePage = ext.save().getUrl();
		//get the id from the pageref
		Id newOppId = savePage.substring(1,19);
		//lookup the newly created opp
		Opportunity newOpp = [select id, RecordTypeId, RecordType.Name, CampaignId,AccountId, Name, CloseDate,CR_Contact_Id__c from Opportunity where Id = :newOppId limit 1]; 
		//make sure the rt got set correctly
		system.assertEquals(rtid,newOpp.RecordTypeId);
		//did it get to the campaign
		system.assertEquals(firstCampaign.id,newOpp.CampaignId);
		//find the contact role
		OpportunityContactRole[] newCR = [select Role, IsPrimary from OpportunityContactRole where OpportunityId = :newOppId and ContactId = :firstContact.id];
		//should be 1
		system.assertEquals(1,newCR.size());
		//org donor role
		system.assertEquals(ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE,newCR[0].Role);
		
		
	}
	static testmethod void testOpenOppListAsDonorChanges () {	
		
		//create an opportunity
		Opportunity theOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS)
		);
		
		//create an Contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName = 'Smith'		
		);
		insert firstContact;
		
		//create an Campaign
		Campaign firstCampaign = new Campaign (
			Name = 'Test Campaign'		
		);
		insert firstCampaign;
		
		//create an Account
		Account firstAccount = new Account (
			Name='XYZ Org'		
		);
		insert firstAccount;
		
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
		//put the contact and account id on the page
		ApexPages.currentPage().getParameters().put('conid', firstContact.id);
		ApexPages.currentPage().getParameters().put('accid', firstAccount.id);
		ApexPages.currentPage().getParameters().put('campid', firstCampaign.id);
		
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
		//pass the controller into the extension
		ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
		//since we have a contact id, we should be in contact mode	
		ext.OppApplicant = 'Organization';	
		system.AssertEquals('Organization',ext.OppApplicant);
		//get a rt id
			// MS mod 10/9/08: use Rectype class to avoid hardcoding rectype name
		//RecordType giftRT = [Select Id from RecordType where SObjectType='Opportunity' and Name='Gift' limit 1];
		/*
		ONEN_RecordTypes rtlookup = new ONEN_RecordTypes ('Opportunity');
		*/
		id rtid = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS);
		ext.oppRecordTypeId = rtid;
		//next step
		//ext.step2();
		//eet a valid close date
		//ext.opportunity.CloseDate = system.Today();
		//dave
		String savePage = ext.save().getUrl();
		//get the id from the pageref
		Id newOppId = savePage.substring(1,19);
		//lookup the newly created opp
		Opportunity newOpp = [select id, RecordTypeId, RecordType.Name, CampaignId,AccountId, Name, CloseDate,CR_Contact_Id__c from Opportunity where Id = :newOppId limit 1]; 
		//make sure the rt got set correctly
		system.assertEquals(rtid,newOpp.RecordTypeId);
		//did it get to the campaign
		system.assertEquals(firstCampaign.id,newOpp.CampaignId);
		//find the contact role
		OpportunityContactRole[] newCR = [select Role, IsPrimary from OpportunityContactRole where OpportunityId = :newOppId and ContactId = :firstContact.id];
		//should be 1
		system.assertEquals(1,newCR.size());
		//org donor role
		system.assertEquals(ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE,newCR[0].Role);
		
		
	}
	
	static testmethod void testMonthlyMembershipPaymentReceived() {	
		
		//create an opportunity
		Opportunity theOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
		);
		
		//create an Contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName = 'Smith'		
		);
		insert firstContact;
		
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
		//put the contact and account id on the page
		ApexPages.currentPage().getParameters().put('conid', firstContact.id);
		
		//pass contact into the controller
		ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
		//pass the controller into the extension
		ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 
		//since we have a contact id, we should be in contact mode	
		ext.OppApplicant = 'Contact';	
		
		ext.oppRecordTypeId = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
		ext.opportunity.Monthly_Gift__c = true;
		//start date for first payment
		ext.bogusOpp.CloseDate = Date.newInstance( 2005,1,1);
		ext.opportunity.Monthly_Gift_Amount__c = 10;
		ext.paymentReceived = true;
		
		String savePage = ext.save().getUrl();
		//get the id from the pageref
		Id newOppId = savePage.substring(1,19);
		//lookup the newly created opp
		Opportunity newOpp = [select id, Amount, Total_Paid__c, Total_Unpaid__c from Opportunity where Id = :newOppId limit 1]; 
		//make sure the rt got set correctly
		system.assertEquals(120,newOpp.Amount);
		system.assertEquals(10,newOpp.Total_Paid__c);
		system.assertEquals(110,newOpp.Total_Unpaid__c);		
		
	}
	

	static testmethod void testMonthlyMembershipAltFY() {	
		
		//create an opportunity
		Opportunity theOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS) 
		);
		
		//create an Contact
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName = 'Smith'		
		);
		insert firstContact;
		
		Test.setCurrentPageReference(new PageReference('Page.newOppWizard'));
		ApexPages.currentPage().getParameters().put('conid', firstContact.id);
		ApexPages.StandardController sc = new ApexPages.standardController(theOpp);
		ONEN_CTRL_NewOppWizard ext = new ONEN_CTRL_NewOppWizard(sc); 

		//since we have a contact id, we should be in contact mode	
		ext.OppApplicant = 'Contact';	
		ext.oppRecordTypeId = GW_RecTypes.GetRecordTypeId ('Opportunity',ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
		ext.opportunity.Monthly_Gift__c = true;
		//start date for first payment
		ext.bogusOpp.CloseDate = Date.newInstance( 2005,1,1);
		ext.opportunity.Monthly_Gift_Amount__c = 10;
		ext.paymentReceived = true;
		
		// set alternate FY to two months prior to current month - SHOULD NOT MATTER ABOUT CURRENT MONTH ejc
/*		if (system.today().month() < 3) {
			ext.FYstartMonth = 10 + system.today().month();
		} else {
			ext.FYstartMonth = system.today().month() - 2;
		}
*/
		// july fiscal year should mean 6 payments from jan 1 start
		ext.FYstartMonth = 7;

		String savePage = ext.save().getUrl();
		//get the id from the pageref
		Id newOppId = savePage.substring(1,19);
		//lookup the newly created opp
		Opportunity newOpp = [select id, Amount, Total_Paid__c, Total_Unpaid__c from Opportunity where Id = :newOppId limit 1]; 
		//make sure the rt got set correctly - should be 10 mos. of payments
		system.assertEquals(60,newOpp.Amount);
		system.assertEquals(10,newOpp.Total_Paid__c);
		system.assertEquals(50,newOpp.Total_Unpaid__c);	
		
		OppPayment__c[] installs = [SELECT Id,Opportunity__c,Amount__c FROM OppPayment__c WHERE Opportunity__c = :newOpp.Id];
		system.assertEquals (6 , installs.size() );	
		
	}	
	
	/*************************************************
	*												 *
	*   TESTS										 *
	*												 *
	**************************************************/
	
	static testmethod void TestInstallments () {
		//point to our VF page
		Test.setCurrentPageReference(new PageReference('Page.installmentWizard'));
		
		//create an opportunity
		Opportunity firstOpp = new Opportunity (
			RecordTypeId = GW_RecTypes.GetRecordTypeId('Opportunity', ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), 
			Name='Test Opp',
			StageName = 'Prospecting',
			CloseDate = System.Today(),
			Amount=100			
		);
		
		insert firstOpp;
		//trigger will have created one mirror payment
		
		//get the created opp Id
		ApexPages.currentPage().getParameters().put('id', firstOpp.id);
		//instantiate the controller for this opp
		ONEN_CTRL_InstallmentWizard controller = new ONEN_CTRL_InstallmentWizard();
				
				
		system.AssertNotEquals(0,controller.getItems().size());
		system.AssertNotEquals(0,controller.getIntervals().size());
		system.AssertNotEquals(0,controller.getIntervalUnits().size());
		//set the interval unit	
		String unit = 'Year';	
		controller.Intervalunit = unit;
		system.AssertEquals(unit,controller.Intervalunit);
		
		//set the number of installments
		Integer paymentCount = 3;
		controller.numberofinstallments = paymentCount;
		system.AssertEquals(paymentCount,controller.numberofinstallments);
		
		//set the interval
		Integer intervalCount = 2;
		controller.interval = intervalCount;
		system.AssertEquals(intervalCount,controller.interval);
		
		//a list for the new payments
		List<OppPayment__c> newPayments = new List<OppPayment__c>();
		//create the new payment objects
		newPayments = controller.getPayments();
		
		//there should be the payment count
		system.AssertEquals(paymentCount,newPayments.size());
		
		//create the installments
		controller.createInstallments();
		
		//query the newly created installments
		OppPayment__c[] createdPayments = [select Id,IsInstallment__c,Date__c from OppPayment__c where Opportunity__c =:firstOpp.id ORDER BY Date__c];
			system.debug ('installments created: ' + createdPayments);
		//should match the payment count
		system.AssertEquals(paymentCount,createdPayments.size());
		//date should be the same
		system.AssertEquals(system.Today(),createdPayments[0].Date__c);
		//next payment date should be out the interval
		system.AssertEquals(system.Today().addYears(intervalCount),createdPayments[1].Date__c);		
		
 		// now chg the Opp's amount & stage, the installments shouldn't chg
		firstOpp.Amount = 1500;
		firstOpp.StageName = 'Closed Won';
		update firstOpp;
		
		OppPayment__c[] Installments = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id ORDER BY Date__c];
		System.AssertEquals ( paymentCount , Installments.size() );
		
		OppPayment__c OP1 = Installments[0];
		System.AssertEquals ( 33, OP1.Amount__c);
		System.AssertEquals ( firstOpp.CloseDate, OP1.Date__c);
		System.AssertEquals ( true , OP1.IsInstallment__c);
		System.AssertEquals ( false , OP1.Paid__c);
		
		// now delete all the installments
		// we should end up w/ one mirror pmt
		
		delete Installments;
		 
		Installments = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :firstOpp.id];
		System.AssertEquals ( 1 , Installments.size() );
		
		OP1 = Installments[0];
		System.AssertEquals ( 1500, OP1.Amount__c);
		System.AssertEquals ( firstOpp.CloseDate, OP1.Date__c);
		System.AssertEquals ( false , OP1.IsInstallment__c);
		System.AssertEquals ( true , OP1.Paid__c);
		
	}
}