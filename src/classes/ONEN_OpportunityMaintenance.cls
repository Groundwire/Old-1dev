public class ONEN_OpportunityMaintenance {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public ONEN_OpportunityMaintenance(Id oppId) {
		if (oppId!=null) {
			opportunityId = oppId;	
		}
	}
	
	public Id opportunityId;
	
	public void setCurrentOpportunityId(Id oppId) {
		opportunityId = oppId;
		
	}
	
	public Opportunity thisOpp { get {return thisOpp;} set {thisOpp = value;} }
	
	public Opportunity newOpp { get {return newOpp;} set {newOpp = value;} }
	//list of opps for the primary donor
	public List<Opportunity> openOpportunitiesForDonor = new List<Opportunity>();
	
	//contact to hold donor data
	public Contact donorForMatchingGift  { get {return donorForMatchingGift;} set {donorForMatchingGift = value;} }
	
	//role for the donor
	public OpportunityContactRole donorRoleOnMatchedGift = new OpportunityContactRole();
	public Id donorIdOnMatchedGift;
	
	//new matching gift
	public Opportunity matchingGift { get {return matchingGift;} set {matchingGift = value;} }
	
	public String matchingGiftName(Date closeDate) {
		//grab Account Name
		Account thisAccount = [Select Name from Account where Id = :matchingGift.AccountId limit 1];
		return thisAccount.Name + ' ' + closeDate.year() +' Matching Gift for ' + donorForMatchingGift.ONEN_Household__r.Name;
	}

	//values used in naming function below	
	public Id primaryContactId;
	public Id primaryAccountId;
	public Id recordTypeId;
	public Date closeDate = system.Today();
	
	public Contact primaryContact = new Contact();
	public Account primaryAccount = new Account();
	//get the primary contact from the id
	public Contact getPrimaryContact() {
		primaryContact = [select HouseholdName__c, FirstName, LastName, Anonymous__c from Contact where Id=:primaryContactId];
		return primaryContact;
	}
	//get the primary account from the id
	public Account getPrimaryAccount() {
		if(primaryAccountId!=null) {
			primaryAccount = [select Name from Account where Id=:primaryAccountId];
			if(primaryAccount.Name == ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME) {
				isIndividualAccount = true;
			} else {
				isIndividualAccount = false;	
			}
			return primaryAccount;
		} else{
			return null;
		}
	}
	//flag if the current account is eh individual account
	public Boolean isIndividualAccount = false;
	
	//get open opps based on thr primary contact
	// chgd 6/09 MMS to use 2 SOQLs rather than subquery since seemed to be tripping SF bug 
	public List<Opportunity> getContactOpenOpps() {
		if(primaryContactId!=null) {
			set<id> conroleIDs = new set<id>();
			OpportunityContactRole[] conroles = [Select OpportunityId from OpportunityContactRole WHERE ContactId=:primaryContactId];
			for (OpportunityContactRole conrole : conroles) {
				conroleIDs.add(conrole.OpportunityId);
			}
			// openOpportunitiesForDonor = [select Id, Name, CloseDate, Amount,CampaignId,RecordTypeId,StageName,Total_Unpaid__c,Next_Payment_Due_Date__c FROM Opportunity WHERE Total_Unpaid__c>0 AND Id IN (Select OpportunityId from OpportunityContactRole WHERE ContactId=:primaryContactId ) Order by CloseDate];
			openOpportunitiesForDonor = [select Id, Name, CloseDate, Amount,CampaignId,RecordTypeId,StageName,Total_Unpaid__c,Next_Payment_Due_Date__c FROM Opportunity WHERE Total_Unpaid__c>0 AND Id IN :conroleIDs Order by CloseDate];
		} else {
			openOpportunitiesForDonor.clear();
		}
		return openOpportunitiesForDonor;
	}
	//get open opps based on the primary org
	public List<Opportunity> getAccountOpenOpps() {
		if(primaryAccountId!=null&&!isIndividualAccount) {
			openOpportunitiesForDonor = [select Id, Name, CloseDate, Amount,CampaignId,RecordTypeId,StageName,Total_Unpaid__c,Next_Payment_Due_Date__c FROM Opportunity WHERE Total_Unpaid__c>0 AND AccountId=:primaryAccountId Order by CloseDate];
		} else {
			openOpportunitiesForDonor.clear();
		}
		return openOpportunitiesForDonor;
	}
	
	public Id cloneThisOpp(Integer Offset, String OffsetUnit) {
		/* SWA 1/18/09 - replacing old record types calls with static ones
		ONEN_RecordTypes OppRecordTypes = new ONEN_RecordTypes('Opportunity');
		*/
		//clone opp
		newOpp = thisOpp.clone(false);

		//set primary account
		primaryAccountId = newOpp.AccountId;
		primaryAccount =getPrimaryAccount();
		
		//clear campaign
		newOpp.CampaignId = null;
		
		/*
		// -------------------------------------------------
		// uncomment this section if using Membership module
		// -------------------------------------------------
		//MS: check if this is a membership, and if so then also increment member dates
		// and set as Renewal
		//SWA 1/18/09 - replacing old record types calls with static ones
		//set<id> mbrRTids =  OppRecordTypes.GetRecordTypeIdSet(ONEN_Constants.OPP_RECTYPES_MEMBERSHIP);
		
		set<id> mbrRTids =  GW_RecTypes.GetRecordTypeIdSet('Opportunity',ONEN_Constants.OPP_RECTYPES_MEMBERSHIP);
		
		if ( OffsetUnit=='Year' && mbrRTids.contains(newOpp.RecordTypeId) ) {
			// redefine the opp vars to include member fields
			thisOpp = [select CloseDate,Account.Name,Amount,AccountId,StageName,RecordTypeId,Fund__c,
						Membership_Start_Date__c, Membership_End_Date__c, Member_Level__c, Membership_Origin__c 
						from Opportunity where Id =:oppToClone];
			newOpp = thisOpp.clone(false);
			// now increment the member fields
			if ( newOpp.Membership_Start_Date__c != null ) {
				newOpp.Membership_Start_Date__c = newOpp.Membership_Start_Date__c.addYears(Offset);
				newOpp.Membership_End_Date__c = newOpp.Membership_End_Date__c.addYears(Offset);
				newOpp.Membership_Origin__c = 'Renewal';
			}
		}
		*/
		
		
		String NewOppName;
		String NewOppPrefix;
		String NewOppSuffix;
		Date NewCloseDate;
		Id primaryContactRoleContactId;
		String primaryContactRoleRole = '';
		
		Id DefaultAccountId = ONEN_DefaultAccount.GetIndividualAccountId();
		//System.debug('primaryContactRole.Role = ' + primaryContactRole.Role);

		
		//MP: Assume this is cloning for one year out
		Integer NewYear;
		Integer NewMonth; 
		String newCloseDateName;
		//set the new dates and names for the new opp based on offset and offsetunit
				
		boolean monthlyGift = false;
		if (OffsetUnit=='Year') {			
			newOpp.CloseDate = thisOpp.CloseDate.addYears(Offset);
		} else if (OffsetUnit=='Month') {
			//set the date and date name for a month offsetunit	
			monthlyGift = true;		
			newOpp.CloseDate = thisOpp.CloseDate.addMonths(Offset);
		}
		

		if(newOpp.AccountId==null||newOpp.AccountId==DefaultAccountId) {
			//swa 2008-11-26: household name field renamed to support xobject formulas
			OpportunityContactRole[] primaryContactRole = [select ContactId, Contact.FirstName, Contact.LastName, Contact.HouseholdName__c, Role, IsPrimary from OpportunityContactRole where OpportunityId = :thisOpp.id and IsPrimary=true];

			if ( primaryContactRole.size() > 0 ) {
				//swa 2008-11-26: household name field renamed to support xobject formulas
				primaryContactId = primaryContactRole[0].ContactId;
				primaryContact = getPrimaryContact();
				primaryContactRoleContactId = primaryContactRole[0].ContactId;
				primaryContactRoleRole = primaryContactRole[0].Role;
			}
			newOpp.Name = oppName('Contact',monthlyGift);
		} else {
			newOpp.Name = oppName('Organization',monthlyGift);
		}
		
		//MP: assign correct stage NOTE: do we assume prospecting?
		newOpp.StageName=ONEN_Constants.OPP_DEFAULT_STAGE;
		
		//MP: Set contact id & role to invoke trigger NOTE: find and put name of said triggers here in comments
		newOpp.CR_Contact_Id__c=primaryContactRoleContactId;
		newOpp.CR_Contact_Role__c=primaryContactRoleRole;						
		//system.debug('Teh opp to be created: ' + newOpp);
		Id newOppId;
		//try {
			//create new opp
			insert newOpp;
			newOppId=newOpp.id;
		//} catch (System.DmlException e) {		
		//	for (Integer k = 0; k < e.getNumDml(); k++) {
		//	 System.debug(e.getDmlMessage(k)); 
		//	}
		//}		
		
		//System.debug('newOpp = ' + newOpp.id); 
		return newOppId;
	}
	//generate a name for the opp
	public String oppName(String oppApplicant,Boolean isMonthly) {
		String name;
		String OppNamePrefix;
		if (oppApplicant=='Contact') {
			OppNamePrefix = primaryContact.HouseholdName__c;
		} else {
		
			//if an org opp, use the name of the Org
			OppNamePrefix = primaryAccount.Name;
				
		}
		/* SWA 1/18/09 - replacing old record types calls with static ones
		//instantiate the RecordType object
		ONEN_RecordTypes OppRecordTypes = new ONEN_RecordTypes('Opportunity');
		*/
		string dateName;
		if(isMonthly) {
			dateName = String.valueOf(newOpp.closeDate.month()) + '/' + String.valueOf(newOpp.closeDate.year());
		}else {
			dateName = String.valueOf(newOpp.closeDate.year());		
		}
		/* SWA 1/18/09 - replacing old record types calls with static ones
		name = OppNamePrefix +  ' ' + dateName + ' ' + OppRecordTypes.GetOppNamingSuffix(OppRecordTypes.GetRecordTypeName(newOpp.RecordTypeId));
		*/
		name = OppNamePrefix +  ' ' + dateName + ' ' + GW_RecTypes.GetOppNamingSuffix(GW_RecTypes.GetRecordTypeName('Opportunity',newOpp.RecordTypeId));
		
		return name;	
	}
}