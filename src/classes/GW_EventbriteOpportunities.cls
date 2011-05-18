public class GW_EventbriteOpportunities {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* class that creates opportunities for eventbrite ticket payments
* uses custom settings for options
* new leads from Eventbrite get opp data populated in response to the CampaignMember 
*    insert trigger, then an extension to the lead conversion class fills the rest of the 
*    opp fields for new event registration opps
-----------------------------------------------------------------------------------------------*/

	public string oppRecTypeName;
	public id oppRecTypeId;
	public string oppContactRole;
	public string oppStageName; 
	
	// constructor - gets settings
	public GW_EventbriteOpportunities() {
        EventbriteOppSettings__c eoSettings = EventbriteOppSettings__c.getInstance();
		if (eoSettings == null) eoSettings = new EventbriteOppSettings__c();
		
		oppContactRole = eoSettings.Contact_Role__c;
		oppStageName = eoSettings.Stage_Name__c;
		if (oppStageName == null) oppStageName = 'Closed Won';

		// get the record type for eventbrite opps
		oppRecTypeName = eoSettings.Opportunity_Record_Type__c;
		if (oppRecTypeName == null)	oppRecTypeName = 'Event Registration';

		Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
		Schema.DescribeSObjectResult d = gd.get('Opportunity').getDescribe();
		Map<String,Schema.RecordTypeInfo> oppRecordTypesByName = d.getRecordTypeInfosByName();
		if (oppRecordTypesByName.containsKey(oppRecTypeName))
			oppRecTypeId = oppRecordTypesByName.get(oppRecTypeName).getRecordTypeId();
	}	
	
	// when a registration is inserted, we need to update the lead record with basic info
	public lead getLeadForUpdate( campaignMember cm ) {
		return new lead(
			id = cm.leadId,
			opportunity_amount__c = cm.ebConnector__Amount_Paid__c,
			opportunity_date__c = (cm.ebConnector__Attendee_Created_Date__c == null) ? null : cm.ebConnector__Attendee_Created_Date__c.date(),
			opportunity_record_type__c = oppRecTypeName,
			opportunity_stage__c = oppStageName,			
			opportunity_description__c = 'Eventbrite order # ' + cm.ebConnector__Order_ID__c +
				((cm.ebConnector__Event_ID__c == null) ? '' : '\nEvent ID: ' + cm.ebConnector__Event_ID__c) +
				((cm.ebConnector__Ticket_ID__c == null) ? '' : '\nTicket ID: ' + cm.ebConnector__Ticket_ID__c) +
				((cm.ebConnector__Quantity__c == null) ? '' : '\nNumber of tickets: ' + cm.ebConnector__Quantity__c) +
				((cm.ebConnector__Event_Date__c == null) ? '' : '\nEvent date: ' + cm.ebConnector__Event_Date__c) +
				((cm.ebConnector__Order_Type__c == null) ? '' : '\nPayment type: ' + cm.ebConnector__Order_Type__c) +
				((cm.ebConnector__Discount__c == null) ? '' : '\nDiscount: ' + cm.ebConnector__Discount__c) +
				((cm.ebConnector__Notes__c == null) ? '' : '\n\nNotes:\n' + cm.ebConnector__Notes__c)
		);
	}
	
	// method to walk through a set of lead converted opps and add eventbrite details
	public void fillEventbriteOppDetails(map<id, opportunity> oppMap, list<Database.leadConvertResult> lcrs) {
		
		// get the set of campaign ids for these opps
		set<id> cmpIds = new set<id>();
		set<id> conIds = new set<id>();
		
		// also map the campaign/contact id combos to their opps
		map<string, opportunity> newOppMap = new map<string, opportunity>();
		
		// walk through all leads looking for an opp and grab its campaign
		for (Database.leadConvertResult lcr : lcrs) { 		
			if (lcr.isSuccess() && oppMap.containsKey(lcr.getLeadId())) {
				
				// get this campaign id into the list
				opportunity o = oppMap.get(lcr.getLeadId());
				if (o.recordTypeId == oppRecTypeId && o.campaignId != null && o.cr_contact_Id__c != null) {
					cmpIds.add(o.campaignId);
					conIds.add(o.cr_contact_Id__c);
					
					// map this new opp for update
					newOppMap.put(o.campaignId + o.cr_contact_Id__c, o);
				}
			}
		}
		system.debug(lcrs);
		system.debug(oppMap);
		system.debug(newOppMap);
		system.debug(cmpIds);
		system.debug(conIds);
		
		// query for all the campaign member data that we might need 						
		for (campaignMember cm:  
				[select id, campaignId, contactId, ebConnector__Quantity__c,
					ebConnector__Order_ID__c, ebConnector__Event_Date__c,
					ebConnector__Order_URL__c, ebConnector__Event_ID__c,
					ebConnector__Ticket_ID__c, ebConnector__Discount__c, 
					ebConnector__Order_Type__c,  ebConnector__Notes__c
					from campaignMember
					where campaignId in : cmpIds
					and contactId in :conIds
					and ebConnector__Amount_Paid__c != null 
					limit 1000] ) {
			
			string memberCode = ((string)(cm.campaignId)) + ((string)(cm.contactId));
			
			if (newOppMap.containsKey(memberCode)) {
		
				opportunity o = newOppMap.get(memberCode);
				o.stagename = oppStageName;
				o.Type = cm.ebConnector__Order_Type__c;
				o.eventbrite_id__c = cm.ebConnector__Order_ID__c;
				o.event_date__c = (cm.ebConnector__Event_Date__c == null) ? null : cm.ebConnector__Event_Date__c.date();
				o.number_of_tickets__c = cm.ebConnector__Quantity__c;
				o.eventbrite_link__c = cm.ebConnector__Order_URL__c;
				if (OppContactRole != null && o.CR_Contact_ID__c != null) o.CR_Contact_Role__c = OppContactRole;
				// optional multicurrency support
				try { 
					o.put('CurrencyISOCode', cm.ebConnector__Currency__c);
				} catch (exception e) {}
			} 
		}
	}
					
	/*
	// 9/2010 ejc
	// this method was written to support creating the payment records automatically via trigger
	// but it did not work because converting leads does not cause the trigger to fire
	// saving this here as a starting point if we decide to write generic support for eventbrite w/o the lead converter 	
	public void processPayments(list<campaignMember> membersWithEventPayments, set<string> orderIds, set<string> contactIds) {
		
		// load settings
		id oppRecType;
		string contactRole;
        EventbriteOppSettings__c eoSettings = EventbriteOppSettings__c.getInstance();

		// only create opps if the settings are there and the checkbox is turned on
		if ((eoSettings != null && eoSettings.Create_Opportunities__c) || isTest) {
			
			// get the record type setting
			string recTypeName = eoSettings.Opportunity_Record_Type__c;
			if (recTypeName != null) {
				Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
				Schema.DescribeSObjectResult d = gd.get('Opportunity').getDescribe();
				Map<String,Schema.RecordTypeInfo> oppRecordTypesByName = d.getRecordTypeInfosByName();
				if (oppRecordTypesByName.containsKey(recTypeName))
					oppRecType = oppRecordTypesByName.get(recTypeName).getRecordTypeId();
			}
			contactRole = eoSettings.Contact_Role__c;
			
			// compile the set of order/contact combinations already in the database
			set<string> orderKeyset = new set<string>();
			for (opportunityContactRole ocr : 
				[select contactId, opportunity.eventbrite_id__c
					from opportunityContactRole
					where opportunity.eventbrite_id__c in : orderIds
					and contactId in :contactIds
					and isPrimary = true limit 1000] ) {
						
				orderKeyset.add(ocr.opportunity.eventbrite_id__c + ocr.contactId);
			}

			// get the contact names to use in the opp names					
			map<id, contact> contactMap = new map<id, contact>(
				[select id, FirstName, lastName from contact where id in :contactIds] );

			// create the opps
			list<opportunity> opps = new list<opportunity>(); 
			for (campaignMember cm : membersWithEventPayments) {
				// avoid duplicates
				if (!orderKeyset.contains( cm.ebConnector__Order_ID__c + cm.contactId )) {
					
					// add this one to the set
					orderKeyset.add( cm.ebConnector__Order_ID__c + cm.contactId );
					
					// build the opp name
					contact c = contactMap.get(cm.contactId);
					string oppName =  (c.firstname + ' ' + c.lastname).trim() + 
							' ' + string.valueOf(system.today().year()) + 
							((recTypeName == null) ? ' Event Registration' : ' ' + recTypeName);
							
					Opportunity opp = new Opportunity(
						Name = oppName,
						campaignId = cm.campaignId,
						cr_contact_role__c = contactRole,
						cr_contact_id__c = cm.contactId,
						stagename = 'Closed Won',
						amount = cm.ebConnector__Amount_Paid__c,
						closedate = date.valueof(cm.ebConnector__Attendee_Created_Date__c),
						Type = cm.ebConnector__Order_Type__c,
						eventbrite_id__c = cm.ebConnector__Order_ID__c,
						event_date__c = date.valueOf(cm.ebConnector__Event_Date__c),
						number_of_tickets__c = cm.ebConnector__Quantity__c,
						eventbrite_link__c = cm.ebConnector__Order_URL__c,
						description = 'Eventbrite order # ' + cm.ebConnector__Order_ID__c +
							'\nEvent ID: ' + cm.ebConnector__Event_ID__c +
							'\nTicket ID: ' + cm.ebConnector__Ticket_ID__c +
							'\nNumber of tickets: ' + cm.ebConnector__Quantity__c +
							'\nEvent date: ' + cm.ebConnector__Event_Date__c +
							'\nPayment type: ' + cm.ebConnector__Order_Type__c +
							((cm.ebConnector__Discount__c == null) ? '' : '\nDiscount: ' + cm.ebConnector__Discount__c) +
							((cm.ebConnector__Notes__c == null) ? '' : '\n\nNotes:\n' + cm.ebConnector__Notes__c)
					);
					
					// optional multicurrency support
					try { 
						opp.put('CurrencyISOCode', cm.ebConnector__Currency__c);
					} catch (exception e) {}
					
					opps.add(opp);
				}
			}
			if (!opps.isEmpty()) insert opps;
		}
	}
*/
	
	static testMethod void testConvertEventbriteLead () {
	
		// create and convert leads with EB payment data
		Campaign c1 = new Campaign(name='Test Eventbrite Campaign 1');
		insert c1;
		Lead[] TestLeads = new Lead[] {
			new Lead(LastName='Test Lead 1', leadsource='Eventbrite'),
			new Lead(LastName='Test Lead 2', firstname='Bob', leadsource='Eventbrite'),
			new Lead(LastName='Test Lead 3', firstname='Joe', email='joe_test@testlead.org', leadsource='Eventbrite')
		};
		insert TestLeads;
		CampaignMember[] TestCMs = new CampaignMember[] {
			new CampaignMember(
				campaignId = c1.id,
				status = 'Sent', 
				LeadId = TestLeads[0].id,
				ebConnector__Amount_Paid__c = 50,
				ebConnector__Attendee_Created_Date__c = system.now().adddays(-7),
				ebConnector__Order_Type__c = 'Paypal',
				ebConnector__Event_ID__c = '123456',
				ebConnector__Ticket_ID__c = '123456',
				ebConnector__Order_ID__c = '123456',
				ebConnector__Event_Date__c = system.today().adddays(7),
				ebConnector__Quantity__c = 1
			),
			new CampaignMember(
				campaignId = c1.id, 
				status = 'Sent', 
				LeadId = TestLeads[1].id,
				ebConnector__Amount_Paid__c = 50,
				ebConnector__Attendee_Created_Date__c = system.now().adddays(-7),
				ebConnector__Order_Type__c = 'Paypal',
				ebConnector__Event_ID__c = '123456',
				ebConnector__Ticket_ID__c = '123456',
				ebConnector__Order_ID__c = '123456',
				ebConnector__Event_Date__c = system.today().adddays(7),
				ebConnector__Quantity__c = 1
			),
			new CampaignMember(
				campaignId = c1.id, 
				status = 'Sent', 
				LeadId = TestLeads[2].id,
				ebConnector__Amount_Paid__c = 7272.89,
				ebConnector__Attendee_Created_Date__c = system.now().adddays(-7),
				ebConnector__Order_Type__c = 'Paypal',
				ebConnector__Event_ID__c = '123456',
				ebConnector__Ticket_ID__c = '123456',
				ebConnector__Order_ID__c = '123456',
				ebConnector__Event_Date__c = system.today().adddays(7),
				ebConnector__Quantity__c = 10
			)
		};
				
		// prepare to convert leads
		// insert a contact
		contact tc = new contact(lastname = 'Test Contact', email='joe_test@testlead.org'); 
		insert tc;

		// simulate the EB connector, which creates campaign memberships
		insert testCMs;
		
		// did they get the donation data?
		system.assertEquals(1, [select count() from lead where opportunity_amount__c = 7272.89 and opportunity_date__c = : system.today().adddays(-7)]);
		Test.StartTest();		
		
		// load leads
		ONEN_LeadConversion_Eventbrite lc = new ONEN_LeadConversion_Eventbrite(10);
		system.debug(lc.loadLeadsBySource('Eventbrite'));
		
		// prepare to convert
		list<ONEN_LeadConversion.ConvertSpec> css = new list<ONEN_LeadConversion.ConvertSpec>();
		ONEN_LeadConversion.ConvertSpec cs;
		cs = new ONEN_LeadConversion.ConvertSpec();
		cs.leadId = TestLeads[0].id;
		cs.contactId = null;
		cs.accountId = null;
		cs.OppId = 'create_new';
		css.add(cs);
		cs = new ONEN_LeadConversion.ConvertSpec();
		cs.leadId = TestLeads[1].id;
		cs.contactId = null;
		cs.accountId = null;
		cs.OppId = 'create_new';
		css.add(cs);
		cs = new ONEN_LeadConversion.ConvertSpec();
		cs.leadId = TestLeads[2].id;
		cs.contactId = tc.id;
		cs.accountId = ONEN_DefaultAccount.getIndividualAccountId();
		cs.OppId = 'create_new';
		css.add(cs);
		 
		// convert
		list<ONEN_LeadConversion.conversion> conv = lc.convertLeads(css);
		Test.StopTest();
		
		// success?		
		system.assert(conv[0].success);
		system.assert(conv[1].success);
		system.assert(conv[2].success);
		
		// how did we do?
		opportunityContactRole[] ocrs = 
			[select contactId, opportunity.eventbrite_id__c, opportunity.name, 
					opportunity.description, opportunity.closedate 
					from opportunityContactRole
					where opportunity.campaignid = : c1.id
					and isPrimary = true limit 1000];
		
		system.debug(ocrs);
		System.AssertEquals ( 3 , ocrs.size() );
		system.assertequals ( system.today().adddays(-7), ocrs[0].opportunity.closedate );
		system.assertequals ( '123456', ocrs[1].opportunity.eventbrite_id__c );
		
	}

}