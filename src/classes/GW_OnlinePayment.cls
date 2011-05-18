public virtual class GW_OnlinePayment extends OnlinePayment {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class processes an online payment, creating an opportunity record. You can call it from 
* web pages or VF pages that take payments, or from a payment notification listener.  
*
* This interface is an attempt to support multiple payment processors in a generic way.  You may
* want to override the methods in this class, but try not to add any processing that is specific
* to a single payment processing application.
*
* Recurring payments are supported; we create a Recurring Payment object to store the metadata
* about the payment, such as frequency, then create one related opportunity for each year's worth
* of payments. Individual payments result in payment installment child records.
*
* TO DO:
*  support multiple items to products
*  compare to authnet and google payments to ensure future compatibility
*  [check on edge cases for setting values back into properties or not using them - e.g. setOppValues]
*  [check on whether unchanged contacts/accounts are getting updated]
-----------------------------------------------------------------------------------------------*/	

	// custom settings are retrieved in the constructor
	public GW_OnlinePaymentSettings__c opSettings;

	public string INDIVIDUAL_ACCOUNT_NAME = ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;
		
	// if a recurring payment record gets created or updated, we store it here
	public recurring_payment__c recurringPayment { get; private set; }

	// if a single installment payment gets created or updated, we store it here
	public oppPayment__c installment { get; private set; }

	// for a new recurring payment, our implementation creates a list of future installments
	// through the end of the year, and passes them back using this property
	public list<oppPayment__c> futureInstallments { get; private set; }

	// these store the set of fields to overwrite if provided
	public set<string> contactOverwrite = new set<string>();
	public set<string> accountOverwrite = new set<string>();

	// need fiscal year start month to be public for tests
	public integer fysm;

	// these objects store the "old" version of the payerAccount and payerContact
	// if they are null, it indicates a new payer (or none at all)
	static account oldAccount;
	static contact oldContact;
	static boolean payerDataSaved;

	// when creating an installment list, this allows us to save the start date for the following year
	static date firstPaymentNextYear;
	
	// constructor
	public GW_OnlinePayment() {
		itemList = new list<OnlinePayment.Item>();
		
		// get settings	- there are defaults for most of them if it isn't set
		opSettings = GW_OnlinePaymentSettings__c.getInstance();
		if (opSettings == null) opSettings = defaultSettings();

		// get the set of fields we will overwrite
		if (opSettings.CONTACT_FIELDS_TO_OVERWRITE__c != null)
			contactOverwrite.addAll(opSettings.CONTACT_FIELDS_TO_OVERWRITE__c.split(';'));
		if (opSettings.ACCOUNT_FIELDS_TO_OVERWRITE__c != null)
			accountOverwrite.addAll(opSettings.ACCOUNT_FIELDS_TO_OVERWRITE__c.split(';'));
	}

	// method to initialize settings when they don't exist, or in tests
	static GW_OnlinePaymentSettings__c defaultSettings() {
		GW_OnlinePaymentSettings__c ops = new GW_OnlinePaymentSettings__c();
		ops.Opp_Stage_for_New_Payments__c = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE;
		ops.Opp_Stage_for_Pending_Payments__c = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE;
		ops.Opp_Stage_for_Lost_Opps__c = ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE;
		ops.Opp_Stage_for_Closed_Opps__c = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE;
		ops.Match_Email_Only_When_Name_Matches__c = true;
		ops.Home_Address_is_Other__c = true;
		ops.Default_Record_Type__c = ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT;
		ops.Create_Pending_Opps__c = true;
		ops.Create_Lost_Opps__c = false;
		ops.Contact_Fields_to_Overwrite__c = 'address;phone';
		ops.Company_Name_Indicates_Org_Payer__c = false;
		return ops;
	}

	/*------------------------------------------------------------------------------------
	* setPayer method
	* tries to match payer data to an existing account or contact
	* if it does not find a match, it creates a new contact (and/or account) for the opp
	* returns true if there is a designated payer one way or another, false for failure
	-------------------------------------------------------------------------------------*/	
	public boolean setPayer() {
		//system.debug('setPayer method');
		//system.debug(this);
		
		payerContact = null;
		payerAccount = null;
		paymentOpp = null;
		payerMatchResult = null;
		boolean success = false;
		
		// first look for an existing recurring payment or opp with the specified transaction Id, 
		// and set the acct/con ids based on that
		if (recurringTxnId != null) {
			recurring_payment__c[] rp = [Select Type__c, Transaction_Id__c, Payment_Period__c, account__c, Occurrences__c, 
				Name, Frequency__c, End_Date__c, Contact__c, Amount__c, account__r.name, account__r.BillingCity, 
				account__r.BillingStreet, account__r.billingCountry, account__r.BillingPostalCode, 
				account__r.billingstate, account__r.phone, account__r.online_payer_id__c,
				contact__r.firstname, contact__r.lastname, contact__r.email, contact__r.Online_Payer_Id__c,	
				contact__r.MailingCity, contact__r.MailingStreet, contact__r.MailingCountry, contact__r.householdName__c,
				contact__r.MailingPostalCode, contact__r.Mailingstate, contact__r.OtherCity, contact__r.OtherStreet, 
				contact__r.OtherCountry, contact__r.OtherPostalCode, contact__r.Otherstate, contact__r.phone, 
				contact__r.anonymous__c, contact__r.homephone, contact__r.fax
				From Recurring_Payment__c where Transaction_Id__c = : recurringTxnId and 
				(end_date__c = null or end_date__c >= THIS_MONTH) 
				order by createddate desc limit 1];
			if (!rp.isEmpty()) {
				recurringPayment = rp[0];
				if (recurringPayment.account__c != null) {
					accountId = recurringPayment.account__c;
					payerAccount = recurringPayment.account__r;
				}
				if (recurringPayment.contact__c != null) {
					contactId = recurringPayment.contact__c;
					payerContact = recurringPayment.contact__r;
				}
			}
		}
		if (txnId != null) {
			opportunity[] opp = [select id, closedate, recordtypeid, recurring_payment__c, 
				isWon, accountid, account.name, account.BillingCity, 
				account.BillingStreet, account.billingCountry, account.BillingPostalCode, 
				account.billingstate, account.phone, account.online_payer_id__c from opportunity 
				where Online_Transaction_Id__c = : txnId or
				(Online_Transaction_Id__c != null and Online_Transaction_Id__c = : parentTxnId) 
				order by createddate desc limit 1];
			if (!opp.isEmpty()) {
				// set the opp and account to what we found
				paymentOpp = opp[0];
				accountId = paymentOpp.accountId;
				payerAccount = paymentOpp.account;
			} else {
				// also check for existing installment payment with this transaction Id
				oppPayment__c[] opmt = [select id, opportunity__c, opportunity__r.accountid, 
					opportunity__r.closedate, opportunity__r.recordtypeid, opportunity__r.iswon,    
					opportunity__r.account.BillingCity,	opportunity__r.account.BillingStreet,
					opportunity__r.account.billingCountry, opportunity__r.account.BillingPostalCode, 
					opportunity__r.account.billingstate, opportunity__r.account.phone, 
					opportunity__r.account.name, opportunity__r.account.online_payer_id__c,
					opportunity__r.recurring_payment__c  // other fields?
					from oppPayment__c where Online_Transaction_Id__c = : txnId limit 1];
				if (!opmt.isEmpty()) {
					installment = opmt[0];
					if (paymentOpp == null) {
						paymentOpp = installment.opportunity__r;
						accountId = paymentOpp.accountId;
						payerAccount = paymentOpp.account;
					}
				}
			}
		}
		// if we found an opp with an account, set company as payer
		if (paymentOpp != null && paymentOpp.AccountId != null && paymentOpp.Account.Name != INDIVIDUAL_ACCOUNT_NAME)
			companyIsPayer = true;
		
		// if we found an opp, get the contact role for it
		if (paymentOpp != null && payerContact == null) {
			opportunityContactRole[] ocr = [select contactId, contact.firstname, contact.lastname, contact.email, 
					contact.Online_Payer_Id__c,	contact.MailingCity, contact.MailingStreet, contact.MailingCountry, 
					contact.MailingPostalCode, contact.Mailingstate, contact.OtherCity, contact.OtherStreet,  contact.householdName__c,
					contact.OtherCountry, contact.OtherPostalCode, contact.Otherstate, contact.phone, contact.anonymous__c,
					contact.homephone, contact.fax from opportunityContactRole  
				where opportunityId = : paymentOpp.id and isPrimary = true limit 1]; 
			if (!ocr.isEmpty()) {
				contactId = ocr[0].contactId;
				payerContact = ocr[0].contact;
			}
		}
		
		// if the contact or account id were prefilled, use them rather than looking for a match
		if (contactId != null) {
			contact[] c = [select id, firstname, lastname, email, Online_Payer_Id__c, householdName__c,
				MailingCity, MailingStreet, MailingCountry, MailingPostalCode, Mailingstate,
				OtherCity, OtherStreet, OtherCountry, OtherPostalCode, Otherstate, anonymous__c,
				phone, homephone, fax, accountid, account.name, account.BillingCity,
				account.BillingStreet, account.billingCountry, account.BillingPostalCode, 
				account.billingstate, account.phone, account.online_payer_id__c from contact
				where id = : contactId limit 1];
			if (!c.isEmpty()) payerContact = c[0];
		}
		if (payerContact == null && accountId != null) {
			account[] a = [select id, name, BillingCity, BillingStreet, billingCountry, BillingPostalCode, 
					billingstate, phone, Online_Payer_Id__c from account
				where id = : accountId limit 1];
			if (!a.isEmpty()) payerAccount = a[0];
		}

		// set the match result property
		if (payerAccount != null || payerContact != null)
			payerMatchResult = MatchResult.TRANSACTION_MATCH;

		// next we try to match to a contact
		if (payerContact == null) {
		
			// look for the payer by email, secondary email, or payerId - an external ID from paypal or authnet
			contact idMatch;
			for (contact c : 
				[select id, firstname, lastname, email, secondary_email__c, Online_Payer_Id__c, householdName__c,
				MailingCity, MailingStreet, MailingCountry, MailingPostalCode, Mailingstate,
				OtherCity, OtherStreet, OtherCountry, OtherPostalCode, Otherstate, anonymous__c,
				phone, homephone, fax, accountid, account.name, account.BillingCity,
				account.BillingStreet, account.billingCountry, account.BillingPostalCode, 
				account.billingstate, account.phone, account.online_payer_id__c from contact 
					where ((Online_Payer_Id__c != null and 
					(Online_Payer_Id__c = : payerId or Online_Payer_Id__c = : email))
					or (email != null and email = : email)
					or (secondary_Email__c != null and secondary_Email__c = : email))
					order by lastModifiedDate limit 10 ] ) {
				
				// if there is a payer Id match, that trumps other criteria
				if ((payerId != null && payerId == c.Online_Payer_Id__c) || 
					(email != null && email == c.Online_Payer_Id__c)) {

					payerContact = c;
					break;
				}
				
				// if there is an email match, check last name/first letter of first name as well
				// replace previously found contact on any exact name match
				if (email != null && 
					(email == c.email || email == c.secondary_Email__c) &&
					((lastName == c.lastName && firstName == c.firstName) ||
					(payerContact == null &&
					(opSettings.MATCH_EMAIL_ONLY_WHEN_NAME_MATCHES__c == false ||
					(lastName == c.lastName && 
						firstName != null && firstName != '' &&
					 	c.firstName != null && c.firstName != '' &&
					 	c.firstName.startsWith(firstName.substring(0,1))))))) {

					payerContact = c;
				}					
			}
		}		

		// set the match result property
		if (payerMatchResult == null && payerContact != null)
			payerMatchResult = MatchResult.CONTACT_MATCH;

		// look for a matching account if we do not already have a contact match 
		if (payerAccount == null && companyName != null && companyName != INDIVIDUAL_ACCOUNT_NAME &&
			(payerContact == null || companyIsPayer == true || opSettings.COMPANY_NAME_INDICATES_ORG_PAYER__c)) {
		
			// look for an account by payerId or account name
			for (account a : 
				[select id, name, BillingCity, BillingStreet, billingCountry, BillingPostalCode, 
					billingstate, phone, Online_Payer_Id__c from account 
					where ((Online_Payer_Id__c != null and 
					(Online_Payer_Id__c = : payerId  or Online_Payer_Id__c = : email))
					or name = : companyName )
					order by lastModifiedDate limit 10 ] ) {
				
				// if there is a payer Id match, that trumps other criteria
				if ((payerId != null && payerId == a.Online_Payer_Id__c) || 
					(email != null && email == a.Online_Payer_Id__c)) {

					payerAccount = a;
					break;
				}
				
				// be sure to favor the right city
				if (payerAccount == null || a.billingCity == city)
					payerAccount = a;
			}
		}		

		// if there is a contact, we want that contact's account (if it isn't the default account)
		if (payerContact != null && payerContact.account != null && 
			payerContact.account.name != INDIVIDUAL_ACCOUNT_NAME &&
			(CompanyName == null || CompanyName.trim() == '' || !opSettings.COMPANY_NAME_INDICATES_ORG_PAYER__c)) {
				
			payerAccount = payerContact.account;
		}

		// set the match result property
		if (payerMatchResult == null && payerAccount != null)
			payerMatchResult = MatchResult.ACCOUNT_MATCH;

		// if we don't have a match, create a payer account
		if (payerAccount == null) { 
			oldAccount = null;
			accountId = null;
			if (companyName != null && companyName != INDIVIDUAL_ACCOUNT_NAME)
				payerAccount = new Account(
					Name = companyName
				);
		} else {
			// create a copy of the existing account to compare later
			oldAccount = payerAccount.clone(true, true);
			accountId = payerAccount.Id;
		}
		
		// is the payer a company?
		if (companyIsPayer == null) companyIsPayer =
			((payerAccount != null && payerContact == null) ||
			(opSettings.COMPANY_NAME_INDICATES_ORG_PAYER__c && CompanyName != null && CompanyName.trim() != '')
				&& companyName != INDIVIDUAL_ACCOUNT_NAME);
						
		// for company opps, update account with any new data - overwrite as specified
		if ( companyIsPayer ) {
			if (payerAccount.BillingStreet == null || (street != null && accountOverwrite.contains('address'))) {
				payerAccount.billingStreet = street;
				payerAccount.billingCity = city;
				payerAccount.billingState = state;
				payerAccount.billingPostalCode = zip;
				payerAccount.billingCountry = country;
			}
			if (payerAccount.phone == null || (phone != null && accountOverwrite.contains('phone')))
				payerAccount.phone = phone;
			if (payerAccount.Online_Payer_Id__c == null)
				payerAccount.Online_Payer_Id__c = (payerId == null) ? email : payerId;

			// fix the match result property
			if (payerMatchResult == MatchResult.CONTACT_MATCH)
				payerMatchResult = MatchResult.ACCOUNT_MATCH;
		}
			
		// if we don't have a match yet, create a contact						
		if (payerContact == null) {
			oldContact = null;
			contactId = null;
			if (lastName != null)
				payerContact = new Contact(
					firstName = firstName,
					lastName = lastName,
					email = email,
					leadsource = (pmtProcessor == Processor.PAYPAL) ? 'Paypal' : 'Online Payment' 				 				
				);
		} else {
			// create a copy of the existing contact to compare later
			oldContact = payerContact.clone(true, true);
			contactId = payerContact.Id;
		}
		
		// set the match result property
		if (payerMatchResult == null) {
			if (companyIsPayer && payerAccount != null)
				payerMatchResult = MatchResult.NEW_ACCOUNT;
			else if (payerContact != null)
				payerMatchResult = MatchResult.NEW_CONTACT;
		}

		// set contact fields - overwrite as specified
		if (payerContact != null) {	
			if (companyIsPayer || !opSettings.HOME_ADDRESS_IS_OTHER__c) {
				if (payerContact.mailingStreet == null || (street != null && contactOverwrite.contains('address'))) {
					payerContact.mailingStreet = street;
					payerContact.mailingCity = city;
					payerContact.mailingState = state;
					payerContact.mailingPostalCode = zip;
					payerContact.mailingCountry = country;
				}
			} else {
				if (payerContact.otherStreet == null || (street != null && contactOverwrite.contains('address'))) {
					payerContact.otherStreet = street;
					payerContact.otherCity = city;
					payerContact.otherState = state;
					payerContact.otherPostalCode = zip;
					payerContact.otherCountry = country;
				}
			}
			if (companyIsPayer) {
				if (payerContact.phone == null || (phone != null && contactOverwrite.contains('phone')))
					payerContact.phone = phone;
			} else {
				if (payerContact.homePhone == null || (phone != null && contactOverwrite.contains('phone')))
					payerContact.homePhone = phone;		
				if (payerContact.Online_Payer_Id__c == null && payerId != null)
					payerContact.Online_Payer_Id__c = payerId;
			}
			if (payerContact.email == null || (email != null && contactOverwrite.contains('email')))
				payerContact.email = email;
		}
	
		// call the method to fill in custom contact or account fields
		if (custom != null) {
			custom = custom.trim();
			
			// interpret JSON to set contact and account fields
			if (custom.startsWith('{')) {
				try {
					if (payerAccount != null)
						payerAccount = (account)(updateSObjectFromJSON('account', (sobject)payerAccount, custom));
					if (payerContact != null)
						payerContact = (contact)(updateSObjectFromJSON('contact', (sobject)payerContact, custom));
				} catch (exception e) {
					system.debug('Failed to update online payer records from JSON in the custom property.');
					system.debug(e);
				}
			}
		}

		// if we have a payer, return true
		//system.debug(this);
		payerDataSaved = false;		
		return (payerAccount != null || payerContact != null);
	}

	/*------------------------------------------------------------------------------------
	* savePayerData method
	* creates (or updates) the account and/or contact for an online payment
	-------------------------------------------------------------------------------------*/	
	public boolean savePayerData() {
		boolean success;
		if (payerDataSaved) { 
			success = true;
		} else {
			success = false;
			try {
				if (payerAccount != null) {
					if (oldAccount == null) {
						insert payerAccount;
						accountId = payerAccount.Id;
					} else if (payerAccount != oldAccount) {
						update payerAccount;
						oldAccount = payerAccount;  // in case we do this again
					}
				}
				if (payerContact != null) {
					if (oldContact == null) {
						insert payerContact;
						contactId = payerContact.id;
					} else if (payerContact != oldContact) {
						update payerContact;
						oldContact = payerContact;  // in case we do this again
					}
				}
				success = true;
			} catch (exception e) {
				throw new OnlinePaymentException('Could not save contact or account for online payment.', e);
			}				
			payerDataSaved = true;	
		}
		return success;	
	}

	/*------------------------------------------------------------------------------------
	* processSinglePayment method
	* creates (or updates) an opportunity for an online payment
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	public boolean processSinglePayment() {
		boolean success = false;
		
		// make sure we have a payer
		if (payerContact != null || payerAccount != null || setPayer()) {

		system.debug('found a payer ' + payerContact);

			// either create an opp, or save a copy of the existing one
			opportunity oldOpp;			
			if (paymentOpp != null) {		
				oldOpp = paymentOpp.clone(true, true);
			} else {
				if (pmtStatus == null || 
					pmtStatus == PaymentStatus.COMPLETED ||
					(opSettings.CREATE_PENDING_OPPS__c &&
						(pmtStatus == PaymentStatus.PENDING ||
						pmtStatus == PaymentStatus.AUTHORIZED)) ||
					(opSettings.CREATE_LOST_OPPS__c &&
						pmtStatus == PaymentStatus.FAILED )) {
								
					paymentOpp = new Opportunity(
						closeDate = system.today(),
						recordTypeId = getPaymentRecordTypeId(
							(itemList != null && itemList.size() > 0) ? itemList[0].name : null ),
						stagename = opSettings.OPP_STAGE_FOR_NEW_PAYMENTS__c,
						online_transaction_id__c = txnId
					);
				}
			}	
				
			if (paymentOpp != null && savePayerData()) {

				// set the opp values
				string dateName = String.valueOf(system.today().year());
				setOppValues( paymentOpp, recurringPayment, installment, dateName, oldOpp );
															
		system.debug('values are set ' + paymentOpp);
												
				try {
					// insert or update the opp
					if (paymentOpp != null) {
						if (oldOpp == null) {
							insert paymentOpp;
						} else if (paymentOpp != oldOpp) {
							update paymentOpp;
			system.debug('I am updating ' + paymentOpp);

							// for completed payments, there may have been an unpaid amount							
							// query for the first unpaid payment of this amount underneath this recurring payment
							if (pmtStatus == PaymentStatus.COMPLETED) {
	
								oppPayment__c[] unpaidInstallment =  
									[select id, opportunity__c, date__c, amount__c, opportunity__r.total_unpaid__c,
										opportunity__r.id, opportunity__r.amount, opportunity__r.stagename 
										From oppPayment__c where paid__c = false and written_off__c = false 
										and opportunity__c = : paymentOpp.id 
										and amount__c = : totalAmount  
										order by date__c limit 1];
										
								if (!unpaidInstallment.isEmpty()) {
							
									// mark the existing installment paid
									installment = unpaidInstallment[0];
									installment.paid__c = true;
									installment.check_date__c = system.today();
									installment.Online_Transaction_ID__c = txnId;
									try {
										update installment;
									} catch (exception e) {
										throw new OnlinePaymentException('Could not update online payment record to paid.', e);
									}
								}
							}
						}

						if (pmtStatus != null && pmtStatus != PaymentStatus.COMPLETED && pmtStatus != PaymentStatus.FAILED) {
							
							// insert an unpaid installment
							oppPayment__c op = new oppPayment__c(
								Amount__c = paymentOpp.Amount,
								date__c = paymentOpp.closeDate,
								isInstallment__c = true,
								opportunity__c = paymentOpp.id,
								opp_for_installment__c = paymentOpp.id,
								paid__c = false
							);
							insert op;
							
							// delete the mirror payment
							oppPayment__c[] mirrorOppPaymentsToDelete = [Select Id from OppPayment__c 
								where IsInstallment__c=false and Opportunity__c=:paymentOpp.id];
					        if (!mirrorOppPaymentsToDelete.isEmpty())
					        	delete mirrorOppPaymentsToDelete;						
						}
						opportunityId = paymentOpp.id;
					}
					success = true;		
				} catch (exception e) {
					throw new OnlinePaymentException('Could not save online payment opportunity.', e);
				}				
			}
		}			
		return success;
	}

	/*------------------------------------------------------------------------------------
	* startRecurringPayments method
	* creates a new recurring payments record for an online recurring payment or subscription,
	* then creates an opportunity with installment pmts through the end of the current fiscal year
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	public boolean startRecurringPayments() {
		boolean success = false;

		// make sure we have a payer
		if (payerContact != null || payerAccount != null || setPayer()) {
	
			// for an update, we will cancel the existing recurring payment and create a new one
			Recurring_Payment__c oldRP = (recurringPayment != null) ? recurringPayment : null;

			// get a new recurring payment
			recurringPayment = createRecurringPayment( startDate );
				
			if (recurringPayment != null && savePayerData()) {	

				// set the id of the payer
				if (companyIsPayer) 
					recurringPayment.account__c = accountId;
				else	
	 				recurringPayment.Contact__c = contactId;

				// save the opp
				system.debug('Saving payment, opportunity, and installment records.');
				system.debug(recurringPayment);
				try {
					// insert the new recurring pmt
					insert recurringPayment;
					
					// create the opp
					paymentOpp = createRecurringPaymentOpp( recurringPayment, startDate );						
					
					// if there was an existing payment, we need to stop it before inserting the new one
					if (oldRP != null) closeRecurringPayment(oldRP, true);

					// get installments through the end of the year - have to do this before inserting the opp to get the total
					futureInstallments = createInstallmentList( recurringPayment, paymentOpp, startDate );

					// now insert the opp, which will get us an Id
					insert paymentOpp;
					system.debug(paymentOpp);

					// set the opp Id for the list of installments, then insert them
					for (OppPayment__c op : futureInstallments) {
						op.opportunity__c = paymentOpp.id;
						op.opp_for_installment__c = paymentOpp.id;
					}
					insert futureInstallments;
					system.debug(futureInstallments);
					
					// remove the obsolete mirror payment
					oppPayment__c[] mirrorOppPaymentsToDelete = [Select Id from OppPayment__c 
						where IsInstallment__c=false and Opportunity__c=:paymentOpp.id];
			        if (!mirrorOppPaymentsToDelete.isEmpty())
			        	delete mirrorOppPaymentsToDelete;

					// set the opp id to send back to the payment notification record
					opportunityId = paymentOpp.id;
					success = true;		

				} catch (exception e) {
					throw new OnlinePaymentException('Could not save recurring online payment records.', e);
				}				
			}
		}			
		return success;
	}	
	
	/*------------------------------------------------------------------------------------
	* processRecurringPayment method
	* creates (or updates) an opportunity for an online payment associated with recurring opp
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	public boolean processRecurringPayment() {
		boolean success = false;
		
		// need a recurring Id, and also someone to own the payment
		if (recurringTxnId != null && (payerContact != null || payerAccount != null || setPayer())) {
			id oppId;

			// create a new recurring payment record if needed; also make sure that
			// the amount of this payment matches the amount of the recurring transaction
			// then save payer data before continuing
			if (((recurringPayment != null && totalAmount == recurringPayment.amount__c) || startRecurringPayments()) 
					&& savePayerData()) {
				
				if (pmtStatus == PaymentStatus.AUTHORIZED) {
					// don't do anything to opp or payments, but report success - because nothing is wrong
					success = true;
					
				} else if (pmtStatus == null || pmtStatus == PaymentStatus.COMPLETED) {

					// set the id of the payer
					if (companyIsPayer) 
						recurringPayment.account__c = accountId;
					else	
		 				recurringPayment.Contact__c = contactId;
				
					// make sure we do not have a repeat transaction id
					if (installment == null) {
				
						// query for the first unpaid payment of this amount underneath this recurring payment
						oppPayment__c[] unpaidInstallment =  
							[select id, opportunity__c, date__c, amount__c, opportunity__r.total_unpaid__c,
								opportunity__r.id, opportunity__r.amount, opportunity__r.stagename 
								From oppPayment__c where paid__c = false and written_off__c = false 
								and opportunity__r.recurring_payment__c = : recurringPayment.id 
								and amount__c = : totalAmount  
								order by date__c limit 1];
		
						boolean fullyPaid = false;
		
						if (!unpaidInstallment.isEmpty()) {
							
							// mark the existing installment paid
							installment = unpaidInstallment[0];
							installment.paid__c = true;
							installment.check_date__c = system.today();
							installment.Online_Transaction_ID__c = txnId;
							try {
								update installment;
		
								// set the opp id to send back to the payment notification record
								opportunityId = installment.opportunity__c;
								paymentOpp = installment.opportunity__r;
		
								fullyPaid = (installment.amount__c == installment.opportunity__r.total_unpaid__c);
		
							} catch (exception e) {
								throw new OnlinePaymentException('Could not update recurring online payment record to paid.', e);
							}
						} else {					
							// create a new opp with one payment paid
							paymentOpp = createRecurringPaymentOpp( recurringPayment, startDate );						
		
							// get installments through the end of the year - have to do this before inserting the opp to get the total
							futureInstallments = createInstallmentList( recurringPayment, paymentOpp, startDate );
		
							try {
								// now insert the opp, which will get us an Id
								insert paymentOpp;
								system.debug(paymentOpp);
			
								// set the opp Id for the list of installments
								for (OppPayment__c op : futureInstallments) {
									op.opportunity__c = paymentOpp.id;
									op.opp_for_installment__c = paymentOpp.id;
								}
								
								// mark the last installment paid
								installment = futureInstallments[0];
								installment.paid__c = true;
								installment.check_date__c = system.today();
								installment.Online_Transaction_ID__c = txnId;
								
								insert futureInstallments;
								system.debug(futureInstallments);
		
								fullyPaid = (futureInstallments[0].amount__c == paymentOpp.Amount);
								
								// remove the obsolete mirror payment
								oppPayment__c[] mirrorOppPaymentsToDelete = [Select Id from OppPayment__c 
									where IsInstallment__c=false and Opportunity__c=:paymentOpp.id];
						        if (!mirrorOppPaymentsToDelete.isEmpty())
						        	delete mirrorOppPaymentsToDelete;
			
								// set the opp id to send back to the payment notification record
								opportunityId = paymentOpp.id;
		
							} catch (exception e) {
								throw new OnlinePaymentException('Could not save recurring online payment records.', e);
							}
						}
						
						// if there are no more installments to pay, create a new opp now
						if (fullyPaid) {
							// save a copy of the old opp, but create a brand new one for the future
							system.debug('inserting new opp for next year');
							opportunity newOpp = createRecurringPaymentOpp( recurringPayment, firstPaymentNextYear );						
			
							// important to reset this variable so contact role creation isn't shortcircuited
							ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
							
							// get installments through the end of the year - have to do this before inserting the opp to get the total
							oppPayment__c[] nextYearInstallments = createInstallmentList( recurringPayment, newOpp, firstPaymentNextYear );
			
							// now insert the opp, which will get us an Id
							try {							
								insert newOpp;
			
								// set the opp Id for the list of installments
								for (OppPayment__c op : nextYearInstallments) {
									op.opportunity__c = newOpp.id;
									op.opp_for_installment__c = newOpp.id;
								}
		
								insert nextYearInstallments;
								
								// remove the obsolete mirror payment
								oppPayment__c[] mirrorOppPaymentsToDelete = [Select Id from OppPayment__c 
									where IsInstallment__c=false and Opportunity__c=:newOpp.id];
						        if (!mirrorOppPaymentsToDelete.isEmpty())
						        	delete mirrorOppPaymentsToDelete;
		
							} catch (exception e) {
								throw new OnlinePaymentException('Could not save future recurring online payment records.', e);
							}
						}
						success = true;
					}
				}
			}
		}
		return success;
	}

	/*------------------------------------------------------------------------------------
	* cancelRecurringPayments method
	* finds and marks the specified recurring payment opp(s) as closed or written off
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	public boolean cancelRecurringPayments() {
		boolean success = false;
		
		if (recurringTxnId != null && setPayer() && recurringPayment != null) {
			
			system.debug('Canceling the recurring payment.');
			try {
				closeRecurringPayment(recurringPayment, false);
				success = true;
			} catch (exception e) {
				throw new OnlinePaymentException('Could not cancel recurring online payment records.', e);
			}						
		}		
		
		return success;	
	}

	/*------------------------------------------------------------------------------------
	* createRecurringPayment method
	* used in both recurring payment methods
	-------------------------------------------------------------------------------------*/	
	virtual recurring_payment__c createRecurringPayment( date pmtStartDate ) {

		if (pmtStartDate == null) pmtStartDate = system.today();
		
		recurring_payment__c rp = new Recurring_Payment__c();
		rp.type__c = ((pmtProcessor == Processor.PAYPAL ? 'Paypal' : 
			(pmtProcessor == Processor.AUTHNET ? 'Authorize.net' : 'Other')));
		rp.Transaction_Id__c = recurringTxnId;
		rp.Payment_Period__c = 
			(pmtPeriod == OnlinePayment.recurringPeriod.DAY) ? 'Day' : 
			(pmtPeriod == OnlinePayment.recurringPeriod.WEEK) ? 'Week' : 
			(pmtPeriod == OnlinePayment.recurringPeriod.YEAR) ? 'Year' : 'Month';
		rp.Frequency__c = (frequency == null) ? 1 : frequency; 
		rp.start_Date__c = system.today();
		rp.Occurrences__c = occurrences; 
		rp.Amount__c = totalAmount;
			
		// build the name in the form "John and Jane Doe Monthly Payment"
		if (companyIsPayer || payerContact == null) {
			rp.name = payerAccount.Name; 
		} else {	
			rp.name = (payerContact.HouseholdName__c != null) ? payerContact.HouseholdName__c : 
				((payerContact.FirstName == null) ? payerContact.LastName : (payerContact.firstName + ' ' + payerContact.lastName));
		}
		rp.name += ((rp.Payment_Period__c == 'Month' && rp.Frequency__c == 1) ? ' Monthly' : ' Recurring') + ' Payment';
		
		return rp; 
	}

	/*------------------------------------------------------------------------------------
	* createRecurringOpp method
	* used in both opp creation methods
	-------------------------------------------------------------------------------------*/	
	virtual opportunity createRecurringPaymentOpp( recurring_payment__c rp, date pmtStartDate ) {

		if (pmtStartDate == null) pmtStartDate = system.today();

		opportunity o = new Opportunity(
			type = getPaymentType(pmtType, pmtProcessor),
			closeDate = system.today(),
			recordTypeId = getPaymentRecordTypeId(
				(itemList != null && itemList.size() > 0) ? itemList[0].name : null ),
			stagename = opSettings.OPP_STAGE_FOR_NEW_PAYMENTS__c,
			recurring_payment__c = rp.id,
			// could be a different frequency than monthly, but that is the name of our fields
			Monthly_Gift__c = true,  	
			Monthly_Gift_Discontinued_Date__c = rp.End_Date__c,
			Monthly_Gift_Amount__c = rp.Amount__c
		);
		
		// get the date string for the opp name
		string dateName = (String.valueOf(pmtStartDate.month()) + '/' + String.valueOf(pmtStartDate.year()));		
		setOppValues(o, rp, installment, dateName, null);
		return o;
	}

	/*------------------------------------------------------------------------------------
	* createInstallmentList method
	* set up payments to the end of the fiscal year, and then set the total opp amount
	-------------------------------------------------------------------------------------*/
	virtual OppPayment__c[] createInstallmentList( recurring_payment__c rp, opportunity pmtOpp, date pmtStartDate ) {	

		decimal installmentTotal = 0; 
		date nextPmt = pmtStartDate = (pmtStartDate != null) ? pmtStartDate : system.today();		
		
		// if occurrences are specified, find out how many are already in the database for past opps
		integer priorInstallments = 0;
		if ( rp.Occurrences__c > 0 ) {
			priorInstallments = [select count() from oppPayment__c 
				where opportunity__r.recurring_payment__r.transaction_id__c = : pmtOpp.recurring_payment__c];
		}
		
		// walk through payment schedule to end of year
		oppPayment__c[] ops = new oppPayment__c[0];		
		do {
			ops.add(
				new OppPayment__c(
					Amount__c = rp.Amount__c,
					date__c = nextPmt,
					isInstallment__c = true,
					paid__c = false
				)
			);
			// add to the total for the opp
			installmentTotal += rp.Amount__c;

			// increment to find the next payment date
			integer fq = (rp.frequency__c != null) ? rp.frequency__c.intValue() : 1;
			
			nextPmt = 
				(rp.Payment_Period__c == 'Day') ? nextPmt.addDays(fq) :
				(rp.Payment_Period__c == 'Week') ? nextPmt.addDays(fq * 7) :
				(rp.Payment_Period__c == 'Year') ? nextPmt.addYears(fq) :
				nextPmt.addMonths(fq);
				 
		} while (fiscalYear(nextPmt) == fiscalYear(pmtStartDate) &&
				(rp.Occurrences__c == null || priorInstallments + ops.size() < rp.Occurrences__c) &&
				(rp.end_Date__c==null || nextPmt <= rp.end_Date__c ));
		
		// set the opp amount
		pmtOpp.amount = installmentTotal;
		
		// keep the next payment date in case we need it to create a future opp
		firstPaymentNextYear = nextPmt;
		
		return ops;
	}

	/*------------------------------------------------------------------------------------
	* closeRecurringPayment method
	* find opps with unpaid payments, delete unpaid payments and adjust opp amount
	* also mark the rp with an end date of today and clear its id
	* used in a couple recurring payment methods
	-------------------------------------------------------------------------------------*/	
	virtual void closeRecurringPayment(recurring_payment__c rp, boolean clearId) {
		
		if (rp.id != null) {
			// query for all the payments for opps with unpaid payments under this recurring pmt id
			oppPayment__c[] paymentsToDelete = [select id, opportunity__c, paid__c, amount__c, 
				opportunity__r.id, opportunity__r.amount, opportunity__r.stagename 
				From OppPayment__c where paid__c = false and written_off__c = false 
				and opportunity__r.recurring_payment__c = : rp.id limit 800 ];  
			
			// map the opps that need updating
			map<id, opportunity> oppMap = new map<id, opportunity>();
			  
			// walk through the payments and decrease the total opp amount by each
			for (oppPayment__c op : paymentsToDelete) {
				opportunity thisOpp = (oppMap.containsKey(op.opportunity__c)) ?
					oppMap.get(op.opportunity__c) : op.opportunity__r;
				thisOpp.amount -= op.amount__c;
				oppMap.put(op.opportunity__c, thisOpp);
			}
				
			// if no payments remain, mark it closed lost
			for (opportunity o : oppMap.values())
				o.stageName = (o.amount == 0) ? 
					opSettings.Opp_Stage_for_Lost_Opps__c :
					opSettings.Opp_Stage_for_Closed_Opps__c ;
				
			// save all the changes
			if (!paymentsToDelete.isEmpty()) 
				delete paymentsToDelete;
				
			if (!oppMap.isEmpty()) 
				update oppMap.values();

			// mark the recurring payment as complete
			rp.end_date__c = system.today();
			if (clearId) rp.transaction_id__c = null;
			update rp;
		}
	}

	/*------------------------------------------------------------------------------------
	* setOppValues method
	* used in both opp creation methods
	-------------------------------------------------------------------------------------*/
	virtual void setOppValues( opportunity o, recurring_payment__c rp, oppPayment__c inst, string dateName, opportunity oldOpp ) {	
		
		boolean isUpdate = (oldOpp != null);
		boolean oppWasAlreadyClosed = (isupdate && oldOpp.isWon);
		string oppSuffix = GW_RecTypes.GetOppNamingSuffix(GW_RecTypes.GetRecordTypeName('Opportunity', o.RecordTypeId));
		
		// set name and role for company or individual - our trigger will create a contact role
		if (companyIsPayer || payerContact == null) {
			o.AccountId = payerAccount.Id;
			if (!isUpdate && payerContact != null) {
				o.CR_Contact_Id__c = payerContact.Id;
				o.CR_Contact_Role__c = ONEN_Constants.OPP_ORG_GIFT_DONOR_ROLE;
				o.CR_HHRoles__c = false;
			}
			o.Name = payerAccount.Name +  ' ' + dateName + ' ' + oppSuffix;
			
		} else {
			
			if (!isUpdate && payerContact != null) {
				o.CR_Contact_Id__c = payerContact.Id;
				o.CR_Contact_Role__c = ONEN_Constants.OPP_GIFT_DONOR_ROLE(ONEN_Constants.OPP_DEFAULT_RECTYPE_CONTACT);
				o.CR_HHRoles__c = true;
			}				
			o.Name = 
				((payerContact.householdName__c != null) ? payerContact.householdName__c :
				(payerContact.firstName == null) ? payerContact.lastName : 
				(payerContact.FirstName + ' ' + payerContact.lastName)) +  ' ' + 
				dateName + ' ' + oppSuffix;				
		}
	
		// set the opp stage based on the payment status
		o.stageName = 
			((pmtStatus == PaymentStatus.PENDING || pmtStatus == PaymentStatus.AUTHORIZED) && !oppWasAlreadyClosed) ? opSettings.OPP_STAGE_FOR_PENDING_PAYMENTS__c : 
			(pmtStatus == PaymentStatus.FAILED || (isUpdate && pmtStatus == PaymentStatus.REVERSED)) ? opSettings.OPP_STAGE_FOR_LOST_OPPS__c :
			opSettings.OPP_STAGE_FOR_NEW_PAYMENTS__c;

		// set the type
		o.Type = getPaymentType(pmtType, pmtProcessor); 
				
		// set the amount
		o.amount = totalAmount;

		// build a description field to display other payment data
		string descr = '' + 
			((cardType != null) ? ('Paid by ' + cardType + ((last4digits != null) ? ' *-' + last4digits : '')) : '') +
			((currencyCode != null) ? '\nCurrency Code: ' + currencyCode : '') +
			((fee != null) ? '\nPayment Fee: ' + fee.format() : '') + 
			((tax != null) ? '\nTax: ' + tax.format() : '') + 
			((shipping != null) ? '\nShipping: ' + shipping.format() : '') + 
			((reasonCode != null) ? '\nReason for transaction pending/failure: ' + reasonCode : '') + 
			((invoice != null) ? '\nInvoice # ' + invoice : '');
					
		// look for multiple items
		// we could create opportunity products or other child records for items, but we'll just log them 
		if (itemList != null && itemList.size() > 1) {
			descr += '\nItems ordered: ';
			for (Item itm : itemList) 
				descr += '\n  ' + ((itm.quantity != null) ? (itm.quantity.format() + ' ') : '') + 
					itm.name + ((itm.code != null) ? (' (' + itm.code + ')') : '');
		} 
				
		// finish the description
		if (memo != null) descr += '\nPayment Memo:\n' + memo;
		if (descr != '') o.description = descr.trim();

		// fill in custom payment fields
		if (custom != null) {
			custom = custom.trim();
			
			// if custom is a campaign id, associate the opp with this campaign
			if (custom.startsWith('701')) {
				try {
					o.campaignId = custom;
				} catch (exception e) { 
					system.debug('Failed to set payment campaign.');
				}
			
			} else if (custom.startsWith('{')) {

				// interpret JSON to set payment fields
				try {
					if (rp != null) {
						rp = (recurring_payment__c)(updateSObjectFromJSON('recurring_payment__c', (sobject)rp, custom));
					}
					if (o != null) {
						o = (opportunity)(updateSObjectFromJSON('opportunity', (sobject)o, custom));
					}
					if (inst != null) {
						inst = (oppPayment__c)(updateSObjectFromJSON('oppPayment__c', (sobject)inst, custom));
					}
				} catch (exception e) {
					system.debug('Failed to update online payment records from JSON in the custom property.');
					system.debug(e);
				}
			}
		}
	}

	/*------------------------------------------------------------------------------------
	* getPaymentRecordTypeId method
	* returns the record type id for a given item name, or else the default item name
	-------------------------------------------------------------------------------------*/	
	protected id getPaymentRecordTypeId( string itemName ) {
		string recType = opSettings.DEFAULT_RECORD_TYPE__c;
		
		if (itemName != null && opSettings.ITEM_RECORD_TYPES__c != null) {
			for (string pair : opSettings.ITEM_RECORD_TYPES__c.split(';')) {
				if (pair.contains(',')) {
					string[] s = pair.split(',');
					if (s[0].trim() == itemName) {
						recType = s[1].trim();
						break;
					}
				}
			}
		}
		return GW_RecTypes.GetRecordTypeId('Opportunity', recType);
	}

	/*------------------------------------------------------------------------------------
	* updateSObjectFromJSON method
	* looks for field values in a json string and sets them in an sobject
	* 
	* JSON in the 'custom' property can take one of two forms:
	*   you can specify generic field name/value pairs for any object, or set fields on a
	*   specific object by setting a value for the object name (e.g. contact, account) 
	*   and then nesting JSON with field values	
	* FORM 1:
	*   {"leadsource": "Secret", "my_custom_field__c": "Sauce"}
	* FORM 2: 
	*   {"contact": {"leadsource": "Secret", "my_custom_field__c": "Sauce"}, 
	*		"account": {"description": "Special" },
	*   	"opportunity": {"leadsource": "Secret", "my_custom_field__c": "Sauce"}, 
	*		"oppPayment__c": {"my_custom_field__c": "something"} }
	*
	* The '__c' suffix on custom fields is optional in the JSON - it will try to find fields with or without
	-------------------------------------------------------------------------------------*/	
	static sobject updateSObjectFromJSON(string objName, sobject o, string js) {
		JSONObject jsobj = new JSONObject(js);
	
		for (string fld : jsobj.keys()) {
			// get the object and value
			object v = jsobj.get(fld);
			string s = jsobj.getString(fld);
			date dt;
			try {
				// check for a date value
				if (s != null && s.indexOf('-')==4 && s.split('-').size()==3) {
					string[] dp = s.split('-');
					dt = date.newInstance(integer.valueOf(dp[0]), integer.valueOf(dp[1]), integer.valueOf(dp[2]));
				}

				// first try adding the custom field suffix				
				if (!fld.endsWith('__c')) {
					if (dt != null)
						o.put(fld + '__c', dt);
					else if (v == null)
						o.put(fld + '__c', null);
					else 
						o.put(fld + '__c', v);

					system.debug('Updated field: ' + objName + '.' + fld);
				}

			} catch (exception e) {
				system.debug('Could not update field: ' + objName + '.' + fld + '__c');
			}

			// next try to add the field as passed in (unless it is an object name)				
			if (fld != 'account' && fld != 'contact' && fld != 'opportunity') {
				try {
					if (dt != null)
						o.put(fld, dt);
					else if (v == null)
						o.put(fld, null);
					else 
						o.put(fld, v);
						
					system.debug('Updated field: ' + objName + '.' + fld);
				} catch (exception e2) {
					system.debug('Could not update field: ' + objName + '.' + fld);
				}
			}				
			
			// if there is nested JSON under the object name, pass it recursively to this function	
			if (fld == objName || (fld + '__c') == objName) {
				JSONObject subobj = jsobj.getJSONObject(fld);
				string nestedJson = subobj.valueToString();
				system.debug(nestedJson);
				if (nestedJson != null && nestedJson.trim().startsWith('{'))
					o = updateSObjectFromJSON(objName, o, nestedJson);
			}		
		}					
		return o;
	}

	/*------------------------------------------------------------------------------------
	* getPaymentType method
	* returns the name of the form of payment, which we use to populate the op type 
	-------------------------------------------------------------------------------------*/	
	public virtual string getPaymentType(PaymentType pt, Processor pp) {
		
		// customize or override if you want different opp type values
		return 
			(pt==PaymentType.CREDITCARD) ? 'Credit Card' : 
			(pt==PaymentType.ECHECK) ? 'E-Check' :
			(pt==PaymentType.EFT) ? 'Electronic Funds Transfer' :
			
			// if none of those types, look at the Processor 
			(pp == Processor.PAYPAL) ? 'Paypal' : 
				(pp == Processor.AUTHNET) ? 'Authorize.net' : 
				'Online Payment';
	}

	/*------------------------------------------------------------------------------------
	* fiscalYear method
	* returns the fiscal year of a date
	-------------------------------------------------------------------------------------*/	
	public integer fiscalYear(date d) {
		// get the fiscal year start month if it isn't filled in
		if (fysm == null)
			fysm = [select fiscalYearStartMonth from organization limit 1].fiscalYearStartMonth;
		
		return //(fysm == null) ? null :
			//(fysm == 1) ? d.year() :
			d.addMonths(1-fysm).year();
	}

	/*------------------------------------------------------------------------------------
	* TESTS
	-------------------------------------------------------------------------------------*/	
	
	static testMethod void testMatching () {
		GW_OnlinePayment opmt;
		account a1 = new account(name='test acct');
		insert a1;
		account a2 = new account(name='another test acct');
		insert a2;
		Contact testCon = new contact(firstname='lily', lastname='testy', accountid=a2.id, email='testing123@bogus.org', secondary_email__c = 'testing345@bogus.org');
		insert testCon;		
		Contact testCon2 = new contact(firstname='bob', lastname='testy', accountid=a2.id, online_payer_id__c='testing567@bogus.org');
		insert testCon2;		

		// find account payer name match - but don't match contact because name is not there
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.companyname='test acct';
		opmt.companyIsPayer = true;
		opmt.email = 'testing123@bogus.org';
		opmt.setPayer();
		system.assert(opmt.companyIsPayer);
		system.assertEquals(a1.id, opmt.payerAccount.Id);
		system.assertEquals(null, opmt.payerContact);
		system.assertEquals(OnlinePayment.MatchResult.ACCOUNT_MATCH, opmt.payerMatchResult);	
			
		// find account payer name match when there is also a contact
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.opSettings.Company_Name_Indicates_Org_Payer__c = true;
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.companyname='test acct';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.email = 'testing123@bogus.org';
		opmt.setPayer();
		system.assert(opmt.companyIsPayer);
		system.assertEquals(a1.id, opmt.payerAccount.Id);
		system.assertEquals(testcon.id, opmt.payerContact.Id);
		system.assertEquals(OnlinePayment.MatchResult.ACCOUNT_MATCH, opmt.payerMatchResult);	
		
		// find contact email match
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.email = 'testing123@bogus.org';
		opmt.setPayer();
		system.assert(!opmt.companyIsPayer);
		system.assertEquals(a2.id, opmt.payerAccount.Id);  // should be contact account, not first test account
		system.assertEquals(testcon.id, opmt.payerContact.Id);
		system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, opmt.payerMatchResult);	
		
		// find contact 2nd email match
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.email = 'testing345@bogus.org';
		opmt.setPayer();
		system.assert(!opmt.companyIsPayer);
		system.assertEquals(a2.id, opmt.payerAccount.Id);  // should be contact account, not first test account
		system.assertEquals(testcon.id, opmt.payerContact.Id);
		system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, opmt.payerMatchResult);	
		
		// favor the payer id over the name
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.email = 'testing567@bogus.org';
		opmt.setPayer();
		system.assertEquals(testcon2.id, opmt.payerContact.Id);
		system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, opmt.payerMatchResult);	

		// find transaction match - should ignore the contact and account settings
		Opportunity testOpp = New Opportunity (
			Name = 'Test Opp 3',
			accountid = a2.id,
			Amount = 25,
			CloseDate = system.Today().adddays(10),
			StageName = 'Prospecting',
			Online_Transaction_Id__c = 'X0X0X'
		);
		insert testOpp;
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.companyname='test acct';
		opmt.email = 'testing123@bogus.org';
		opmt.setPayer();
		system.assertEquals(a2.id, opmt.payerAccount.Id);
		system.assert(opmt.companyIsPayer);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// find no match - create contact and account
		a1.online_payer_id__c = null;
		update a1;
		a2.online_payer_id__c = null;
		update a2;
		testCon.online_payer_id__c = null;
		update testCon;		
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X1X1X';
		opmt.firstname='NOTlily';
		opmt.lastname='NOTtesty';
		opmt.email = 'testing345@bogus.org';
		opmt.setPayer();
		system.assert(!opmt.companyIsPayer);
		system.assertEquals(null, opmt.payerAccount); 
		opmt.savePayerData();
		system.assertEquals([select id from contact where lastname = 'NOTtesty' and firstname = 'NOTlily' limit 1].id, opmt.contactId);
		system.assertEquals(OnlinePayment.MatchResult.NEW_CONTACT, opmt.payerMatchResult);
	}
	
	static testMethod void testNewPmtNewAccount () {
		
		// process a payment from a brand new account
		GW_OnlinePayment opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.opSettings.ITEM_RECORD_TYPES__c = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS + ',' + ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processSinglePayment();
		
		// verify that the opp closed
		opportunity[] o1 = [select id, name, type, accountid, stagename, recordtypeid, amount, closedate 
			from opportunity where account.name = 'testco test industries'];
		system.assertEquals(system.today(), o1[0].closedate);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o1[0].stagename);
		system.assertEquals(12345, o1[0].amount);
		system.assertEquals('Paypal', o1[0].type);
		system.assertEquals(o1[0].id, opmt.opportunityId);
		system.assertEquals(o1[0].accountid, opmt.accountId);
		system.assertEquals(null, opmt.payerContact);
		system.assertEquals(OnlinePayment.MatchResult.NEW_ACCOUNT, opmt.payerMatchResult);	
		
		// test that the record type was set properly
		system.assertEquals(ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS, 
			GW_RecTypes.getRecordTypeName('Opportunity', o1[0].recordtypeid));
		system.assert(o1[0].name.contains(ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS), o1[0].name);
	}

	static testMethod void testNewPmtNewContact () {
		
		// process an opp for a brand new contact
		GW_OnlinePayment opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtType = OnlinePayment.PaymentType.CREDITCARD;
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processSinglePayment();
		
		// verify that the opp and role are there
		opportunityContactRole[] o1 = [select id, opportunityid, opportunity.stagename, opportunity.accountid, 
			opportunity.name, opportunity.type,	opportunity.recordtypeid, opportunity.amount, 
			opportunity.closedate, contactid, contact.homephone from opportunitycontactrole
			where opportunity.online_transaction_id__c = 'X0X0X'];
		system.assertEquals(system.today(), o1[0].opportunity.closedate);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o1[0].opportunity.stagename);
		system.assertEquals(12345, o1[0].opportunity.amount);
		system.assertEquals('Credit Card', o1[0].opportunity.type);
		system.assertEquals(null, o1[0].opportunity.accountid);
		system.assertEquals(o1[0].opportunityid, opmt.opportunityId);
		system.assertEquals(o1[0].contactid, opmt.contactId);
		system.assertEquals(o1[0].contactid, opmt.payerContact.Id);
		system.assertEquals(opmt.phone, o1[0].contact.homephone);
		system.assert(o1[0].opportunity.name.contains('lily testy'), o1[0].opportunity.name);
		system.assertEquals(OnlinePayment.MatchResult.NEW_CONTACT, opmt.payerMatchResult);	

		// test that the record type was set properly
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, 
			GW_RecTypes.getRecordTypeName('Opportunity', o1[0].opportunity.recordtypeid));
		system.assert(o1[0].opportunity.name.contains(ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS), o1[0].opportunity.name);
	}

	static testMethod void testNewPmtExistingContact () {
		
		// process a new contact opp
		account a1 = new account(name='test acct');
		insert a1;
		Contact testCon = new contact(firstname='lily', lastname='testy', 
			homephone='do not overwrite', otherstreet='overwrite', email='testing123@bogus.org');
		insert testCon;		
		campaign cmp = new campaign(name='test campaign');
		insert cmp;
		test.startTest();
		
		// create a new payment
		GW_OnlinePayment opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.contactOverwrite = new set<string>{'address'};
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.street = 'newaddress';
		opmt.city = 'newcity';
		opmt.totalAmount = 12345;
		opmt.custom = string.valueOf(cmp.id);
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processSinglePayment();
		
		// verify that the opp closed
		opportunity[] o1 = [select id, accountid, recordtypeid, stagename, campaignid, closedate 
			from opportunity where  Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(system.today(), o1[0].closedate);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o1[0].stagename);
		system.assertEquals(cmp.id, o1[0].campaignid);
		system.assertEquals(o1[0].id, opmt.opportunityId);
		system.assertEquals(testCon.id, opmt.contactId);
		system.assertEquals(testCon.id, opmt.payerContact.Id);
		contact con1 = [select id, otherstreet, homephone from contact where id=:testcon.id];
		system.assertEquals('newaddress', con1.otherstreet);
		system.assertEquals('do not overwrite', con1.homephone);
		system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, opmt.payerMatchResult);	

		// process the same opp txn_id again
		// make sure no dupe is created
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.custom = string.valueOf(cmp.id);
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processSinglePayment();
		opportunity[] o2 = [select id from opportunity where Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(1, o2.size());	
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
	}
		
	static testMethod void testExistingPmtExistingContact () {
		
		// process a contact opp that already exists; opp should get marked closed
		account a1 = new account(name='test acct');
		insert a1;
		Contact testCon = new contact(firstname='lily', lastname='testy', email='testing123@bogus.org');
		insert testCon;		
		Opportunity testOpp = New Opportunity (
			Name = 'Test Opp 3',
			accountid = a1.id,
			Amount = 25,
			CloseDate = system.Today().adddays(10),
			StageName = 'Prospecting',
			CR_Contact_Id__c = testCon.Id,
			CR_Contact_Role__c = 'Individual Donor',
			Online_Transaction_Id__c = 'X0X0X'
		);
		insert testOpp;
		test.startTest();
		
		// create a payment that matches
		GW_OnlinePayment opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processSinglePayment();
		
		// verify that the opp closed and got its mirror oppPayment record
		opportunity[] o1 = [select id, stagename, amount, closedate from opportunity where id=:testOpp.id];
		system.assertEquals(system.today(), o1[0].closedate);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o1[0].stagename);
		system.assertEquals(12345, o1[0].amount);
		system.assertEquals(testOpp.id, opmt.opportunityId);
		system.assertEquals(testCon.id, opmt.contactId);
		system.assertEquals(testCon.id, opmt.payerContact.Id);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
	}
	
	static testMethod void testNewPendingPayment () {
		GW_OnlinePayment opmt;
		account a1 = new account(name='test acct');
		insert a1;
		Contact testCon = new contact(firstname='lily', lastname='testy', email='testing123@bogus.org');
		insert testCon;		
		test.startTest();

		// process an authorized pmt with option off
		// nothing should happen, because we don't create an opp until we get the money
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.opSettings.Create_Pending_Opps__c = false;
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.AUTHORIZED;
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processSinglePayment();
		opportunity[] o1 = [select id from opportunity where Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(0, o1.size());	
		
		// process a pending pmt with option on
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.PENDING;
		opmt.txnId = 'X1X1X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processSinglePayment();
		opportunity[] o2 = [select id, stagename, total_unpaid__c from opportunity where Online_Transaction_Id__c = 'X1X1X'];
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o2[0].stagename);	
		system.assertEquals(12345, o2[0].total_unpaid__c);	
		system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, opmt.payerMatchResult);	

		// process the payment notification
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.txnId = 'X1X1X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processSinglePayment();
		opportunity[] o7 = [select id, stagename, total_unpaid__c from opportunity where Online_Transaction_Id__c = 'X1X1X'];
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o7[0].stagename);	
		system.assertEquals(0, o7[0].total_unpaid__c);	
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	

		// process a failed pmt for one we already have
		// nothing should happen
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.FAILED;
		opmt.txnId = 'X1X1X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processSinglePayment();
		opportunity[] o4 = [select id, stageName from opportunity where Online_Transaction_Id__c = 'X1X1X'];
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE, o4[0].stagename);	
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	

		// process a failed pmt we don't have
		// nothing should happen
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.FAILED;
		opmt.txnId = 'X2X2X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processSinglePayment();
		opportunity[] o3 = [select id from opportunity where Online_Transaction_Id__c = 'X2X2X'];
		system.assertEquals(0, o3.size());	
	}
	
	static testMethod void testSingleAuthThenCapturePayment () {
		GW_OnlinePayment opmt;
		account a1 = new account(name='test acct');
		insert a1;
		Contact testCon = new contact(firstname='lily', lastname='testy', email='testing123@bogus.org');
		insert testCon;	
		
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		
		Opportunity testOpp = New Opportunity (
			Name = 'Test Opp 3',
			Amount = 25,
			CloseDate = system.Today(),
			StageName = opmt.opSettings.Opp_Stage_for_New_Payments__c,
			CR_Contact_Id__c = testCon.Id,
			CR_Contact_Role__c = 'Individual Donor',
			Online_Transaction_Id__c = 'X0X0X'
		);
		insert testOpp;
			
		test.startTest();

		// process an authorized pmt with option off
		// nothing should happen, because we don't create an opp until we get the money
		
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.txnId = 'X0X0X';
		opmt.totalAmount = 25;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 25 ));
		opmt.processSinglePayment();
		opportunity[] o1 = [select id, stageName from opportunity where Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(opmt.opSettings.Opp_Stage_for_New_Payments__c, o1[0].StageName);
		system.assertEquals(o1[0].id, opmt.OpportunityId);
		
		//Payment_Notification__c[] pn1 = [select id, IsProcessed__c from Payment_Notification__c where Transaction_Id__c = 'X0X0X'];	
		//system.assertEquals(true, pn1[0].IsProcessed__c);
			
	}
	
	static testMethod void testNewRecurringNewContact () {

		GW_OnlinePayment opmt;
		
		// process a new recurring pmt signup - monthly
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtPeriod = OnlinePayment.RecurringPeriod.MONTH;
		opmt.frequency = 1;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.custom = '{nextstep:"justice"}';
		opmt.startRecurringPayments();
		system.assertEquals(OnlinePayment.MatchResult.NEW_CONTACT, opmt.payerMatchResult);	

		// check for recurring pmt and opp with 2 installments
		opportunity[] o1 = [select id, amount, total_unpaid__c, recurring_payment__c, recurring_payment__r.name, 
			total_paid__c, recurring_payment__r.amount__c, nextstep from opportunity 
			where recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'];
		system.assertEquals(24690, o1[0].amount);	
		system.assertEquals('justice', o1[0].nextstep);	

		oppPayment__c[] op0 = [select id, paid__c, amount__c, isinstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'];
		system.assertEquals(2, op0.size());			
			
		system.assertEquals(0, o1[0].total_paid__c);	
		system.assertEquals(24690, o1[0].total_unpaid__c);	
		system.assertEquals(12345, o1[0].recurring_payment__r.amount__c);	
		
		// important to reset this variable so contact role creation isn't shortcircuited
		ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
		
		// process first payment
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processRecurringPayment();
		
		// check that it gets marked paid
		oppPayment__c[] op1 = [select id, check_date__c, opportunity__r.amount, opportunity__r.total_unpaid__c, 
			opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.transaction_id__c from oppPayment__c 
			where Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(opmt.recurringPayment.id, op1[0].opportunity__r.recurring_payment__c);	
		system.assertEquals('Y0Y0Y', op1[0].opportunity__r.recurring_payment__r.transaction_id__c);	
		system.assertEquals(system.today(), op1[0].check_date__c);	
		system.assertEquals(12345, op1[0].opportunity__r.total_unpaid__c);	
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	

		// do not take this out - you might run into governor limits
		test.startTest();

		// important to reset this variable so contact role creation isn't shortcircuited
		ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;
		
		// process the other payment
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X1X1X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processRecurringPayment();
		
		// check that it gets marked paid, also new opp created with 12 installments
		oppPayment__c[] op2 = [select id, check_date__c, opportunity__c, date__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.debug(op2);
		system.assertEquals(14, op2.size());
		system.assertEquals('X1X1X', op2[1].online_transaction_id__c);
		system.assertEquals(true, op2[1].isInstallment__c);
		system.assertEquals(system.today(), op2[1].check_date__c);
		system.assertEquals(24690, op2[1].opportunity__r.amount);
		system.assertEquals(0, op2[1].opportunity__r.total_unpaid__c);	
		system.assertEquals(148140, op2[2].opportunity__r.amount);
		system.assertEquals(148140, op2[2].opportunity__r.total_unpaid__c);
		system.assertEquals(opmt.opportunityId, op2[0].opportunity__c);	
		system.assertEquals(system.today().addmonths(2), op2[2].date__c);	
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// check that all three opps have a contact role
		opportunityContactRole[] ocr1 = [select id, opportunityid, opportunity.stagename, opportunity.accountid, 
			opportunity.name, opportunity.type,	opportunity.recordtypeid, opportunity.amount, 
			opportunity.closedate, contactid, contact.homephone from opportunitycontactrole
			where opportunity.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by createddate];
		system.assertEquals(ocr1[0].opportunityid, o1[0].Id);
		system.assertEquals(ocr1[0].contactid, opmt.contactId);
		system.assertEquals(ocr1[1].opportunityid, op2[2].opportunity__c);
		system.assertEquals(ocr1[1].contactid, opmt.contactId);
				
		// important to reset this variable so contact role creation isn't shortcircuited
		ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;

		// process another payment
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X2X2X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processRecurringPayment();
		
		// installment gets marked paid
		oppPayment__c[] op3 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(14, op3.size());	
		system.assertEquals('X2X2X', op3[2].online_transaction_id__c);
		system.assertEquals(true, op3[2].isInstallment__c);
		system.assertEquals(system.today(), op3[2].check_date__c);
		system.assertEquals(24690, op3[1].opportunity__r.amount);
		system.assertEquals(0, op3[1].opportunity__r.total_unpaid__c);	
		system.assertEquals(148140, op3[2].opportunity__r.amount);
		system.assertEquals(135795, op3[2].opportunity__r.total_unpaid__c);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// process the same txn_id again
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X2X2X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processRecurringPayment();
		
		// nothing should happen - already paid
		oppPayment__c[] op4 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(14, op4.size());	
		system.assertEquals('X2X2X', op4[2].online_transaction_id__c);
		system.assertEquals(24690, op4[1].opportunity__r.amount);
		system.assertEquals(0, op4[1].opportunity__r.total_unpaid__c);	
		system.assertEquals(148140, op4[2].opportunity__r.amount);
		system.assertEquals(135795, op4[2].opportunity__r.total_unpaid__c);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// important to reset this variable so contact role creation isn't shortcircuited
		ONEN_OpportunityContactRoles.haveCheckedContactRoles = false;

		// process a new payment, but it is pending
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.PENDING;
		opmt.reasonCode = 'Bad credit, man.';
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X3X3X';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.processRecurringPayment();
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// third payment should NOT get marked paid
		oppPayment__c[] op5 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c, paid__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(false, op5[3].paid__c);
		system.assertEquals(148140, op5[3].opportunity__r.amount);
		system.assertEquals(135795, op5[3].opportunity__r.total_unpaid__c);
		
		// process cancellation of subscription
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.cancelRecurringPayments();
		
		// recurring pmt should get closed
		// opp should get unpaid payments deleted, amount adjusted
		oppPayment__c[] op6 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.end_date__c,
			opportunity__r.total_paid__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(3, op6.size());	
		system.assertEquals(system.today(), op6[1].opportunity__r.recurring_payment__r.end_date__c);
		system.assertEquals(24690, op6[1].opportunity__r.amount);
		system.assertEquals(0, op6[1].opportunity__r.total_unpaid__c);	
		system.assertEquals(12345, op6[2].opportunity__r.amount);
		system.assertEquals(12345, op6[2].opportunity__r.total_paid__c);		
		system.assertEquals(0, op6[2].opportunity__r.total_unpaid__c);		
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
	}	
	
	static testMethod void testRecurringNewAccount () {
		GW_OnlinePayment opmt;
		
		// process a new recurring pmt signup - monthly, not limited
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(-2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtPeriod = OnlinePayment.RecurringPeriod.MONTH;
		opmt.frequency = 1;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.startRecurringPayments();
		
		// check for recurring payment, and opp with 10 installments
		opportunity[] o1 = [select id, amount, total_unpaid__c, recurring_payment__c, recurring_payment__r.name, 
			recurring_payment__r.amount__c from opportunity 
			where recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'];
		system.assertEquals(123450, o1[0].amount);	
		system.assertEquals(123450, o1[0].total_unpaid__c);	
		system.assertEquals(12345, o1[0].recurring_payment__r.amount__c);	
		system.assertEquals(OnlinePayment.MatchResult.NEW_ACCOUNT, opmt.payerMatchResult);	

		// process payment 
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(-2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processRecurringPayment();
		
		// check that payment is marked paid
		opportunity[] o2 = [select id, amount, total_paid__c, recurring_payment__c, recurring_payment__r.name, 
			recurring_payment__r.amount__c from opportunity 
			where recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'];
		system.assertEquals(12345, o2[0].total_paid__c);	
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// process update of subscription to quarterly
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.opSettings.ITEM_RECORD_TYPES__c = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS + ',' + ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
		opmt.fysm = system.today().addmonths(-2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtPeriod = OnlinePayment.RecurringPeriod.MONTH;
		opmt.frequency = 3;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.startRecurringPayments();
		
		// first RP should get closed, opp should get adjusted to amount paid
		oppPayment__c[] op1 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.end_date__c,
			opportunity__r.total_paid__c, opportunity__r.recurring_payment__r.transaction_id__c from oppPayment__c 
			where opportunity__r.recurring_payment__c = : o2[0].recurring_payment__c order by date__c];
		system.assertEquals(1, op1.size());	
		system.assertEquals(null, op1[0].opportunity__r.recurring_payment__r.transaction_id__c);
		system.assertEquals(12345, op1[0].opportunity__r.amount);	
		system.assertEquals(0, op1[0].opportunity__r.total_unpaid__c);
		system.assertEquals(system.today(), op1[0].opportunity__r.recurring_payment__r.end_date__c);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
			
		// second RP should get created with opp and 4 payments
		oppPayment__c[] op2 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.end_date__c,
			opportunity__r.total_paid__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(4, op2.size());	
		system.assertEquals(49380, op2[1].opportunity__r.amount);
		system.assertEquals(49380, op2[1].opportunity__r.total_unpaid__c);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
		
		// process cancellation of unpaid subscription
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.email = 'testing123@bogus.org';
		opmt.firstname='lily';
		opmt.lastname='testy';
		opmt.phone = '(123) 555-1212';
		opmt.cancelRecurringPayments();
		
		// opp gets marked closed lost, RP closed
		oppPayment__c[] op3 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.end_date__c,
			opportunity__r.stagename, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by createddate];
		system.assertEquals(1, op3.size());	
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE, op3[0].opportunity__r.stagename);
		system.assertEquals(0, op3[0].opportunity__r.total_unpaid__c);
		system.assertEquals(system.today(), op3[0].opportunity__r.recurring_payment__r.end_date__c);
		system.assertEquals(OnlinePayment.MatchResult.TRANSACTION_MATCH, opmt.payerMatchResult);	
	}
		
	static testMethod void testRecurringRandom() {
		GW_OnlinePayment opmt;
		
		// process a recurring payment for a recurring pmt ID we have not ever seen
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(-2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processRecurringPayment();
		
		// new monthly RP should get created, also opp with payments, one paid
		
		// check for recurring payment, and opp with 10 installments
		opportunity[] o1 = [select id, amount, total_paid__c, recurring_payment__c, recurring_payment__r.name, 
			recurring_payment__r.amount__c from opportunity 
			where recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'];
		system.assertEquals(123450, o1[0].amount);	
		system.assertEquals(12345, o1[0].recurring_payment__r.amount__c);	
		system.assertEquals(12345, o1[0].total_paid__c);	
		system.assertEquals(OnlinePayment.MatchResult.NEW_ACCOUNT, opmt.payerMatchResult);	
	}	

	static testMethod void testRecurringNoOpenPmts() {
		
		account a1 = new account(name = 'testco test industries', online_payer_id__c = 'testing@bogus.org');
		
		GW_OnlinePayment opmt;
		
		// start a recurring payment, then write off the payment and try to process a payment afterwards
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtPeriod = OnlinePayment.RecurringPeriod.YEAR;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.payerid = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.totalAmount = 12345;
		opmt.startRecurringPayments();

		// verify that the opp is there
		opportunity[] o1 = [select id, name, accountid, stagename, recordtypeid, amount, closedate 
			from opportunity where account.name = 'testco test industries'];
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o1[0].stagename);
		
		// write off the payment
		oppPayment__c[] op0 = [select id from oppPayment__c where opportunity__c = : o1[0].id];
		op0[0].written_off__c = true;
		update op0;

		// mark the opp as lost		
		o1[0].stagename = ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE;
		update o1;		

		// process a payment now
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X0X0X';
		opmt.payerid = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.totalAmount = 12345;
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processRecurringPayment();
		
		// there should be 3 opps - one closed lost, one all paid, one for next year
		opportunity[] o2 = [select id, name, type, stagename from opportunity 
			where account.name = 'testco test industries' order by createddate];
		system.debug(o2);
		system.assertEquals(3, o2.size());	
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE, o2[0].stagename);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o2[1].stagename);
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE, o2[2].stagename);
		system.assertEquals('Paypal', o2[0].type);
		system.assertEquals('Paypal', o2[1].type);
		system.assertEquals('Paypal', o2[2].type);
		
		// each of the two won opps has one pmt	
		oppPayment__c[] op3 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.end_date__c,
			date__c, opportunity__r.stagename, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'
			and opportunity__r.account.name = 'testco test industries' order by createddate, date__c];
		system.assertEquals(3, op3.size());	
		system.assertEquals(0, op3[1].opportunity__r.total_unpaid__c);
		system.assertEquals(12345, op3[2].opportunity__r.total_unpaid__c);
		system.assertEquals(system.today().addyears(1), op3[2].date__c);
	}

	static testMethod void testRecurringWrongAmount () {
		GW_OnlinePayment opmt;
		
		// process a recurring payment with an amount different than the payment record
		// it should be the same as updating the recurring payment - close the old, create the new
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(-2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.pmtPeriod = OnlinePayment.RecurringPeriod.MONTH;
		opmt.frequency = 1;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 12345;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 12345 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.startRecurringPayments();

		// check that payment is marked paid
		opportunity[] o2 = [select id, amount, total_paid__c, recurring_payment__c, recurring_payment__r.name, 
			recurring_payment__r.amount__c from opportunity 
			where recurring_payment__r.Transaction_Id__c = 'Y0Y0Y'];
		system.assertEquals(123450, o2[0].amount);	
				
		// process payment for wrong amount 
		opmt = new GW_OnlinePayment();
		opmt.opSettings = defaultSettings();
		opmt.fysm = system.today().addmonths(-2).month();
		opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
		opmt.recurringTxnId = 'Y0Y0Y';
		opmt.txnId = 'X0X0X';
		opmt.email = 'testing123@bogus.org';
		opmt.companyname='testco test industries';
		opmt.phone = '(123) 555-1212';
		opmt.totalAmount = 54321;
		opmt.itemList = new list<OnlinePayment.Item>();
		opmt.itemList.add(new OnlinePayment.Item( ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS, '', 1, 54321 ));
		opmt.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		opmt.processRecurringPayment();
		
		// first RP should get closed, opp should be closed lost
		opportunity[] o3 = [select id, amount, stagename, total_unpaid__c, recurring_payment__r.end_date__c,
			total_paid__c, recurring_payment__r.transaction_id__c from opportunity 
			where recurring_payment__c = : o2[0].recurring_payment__c];
		system.assertEquals(1, o3.size());	
		system.assertEquals(0, o3[0].amount);	
		system.assertEquals(0, o3[0].total_unpaid__c);	
		system.assertEquals(ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE, o3[0].stagename);
		system.assertEquals(system.today(), o3[0].recurring_payment__r.end_date__c);
		system.assertEquals(null, o3[0].recurring_payment__r.transaction_id__c);
			
		// second RP should get created with opp and 10 payments
		oppPayment__c[] op2 = [select id, check_date__c, opportunity__c, opportunity__r.amount, online_transaction_id__c,
			opportunity__r.total_unpaid__c, opportunity__r.recurring_payment__c, opportunity__r.recurring_payment__r.end_date__c,
			opportunity__r.total_paid__c, isInstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(10, op2.size());	
		system.assertEquals(543210, op2[0].opportunity__r.amount);
		system.assertEquals(54321, op2[0].opportunity__r.total_paid__c);
		
	}
	
	static testMethod void testJSONparsing () {	
		
		// sample JSON you can send via the custom field
		string js = '{"do_not_solicit__c":true, "homephone": "(360) 555-1212",' + 
			' "contact": {"mailingstate":"NY", "mailingcity":null, ' +
			' "birthdate":"1999-09-09","bogus_field__c":"nada"}, ' + 
			' "account":{"billingcity":"Seattle"},' + 
			' "description": "Created by our nifty payment website."}';

		// try some contact parsing		
		contact con = new contact(lastname = 'smith', mailingcity = 'Portland', birthdate = system.today().addyears(-40));
		account acct = new account(name = 'smithco');
		con = (contact)(updateSObjectFromJSON('contact', (sobject)con, js));
		system.assertEquals('NY', con.mailingstate);
		system.assertEquals(true, con.do_not_solicit__c);
		system.assertEquals('(360) 555-1212', con.homephone);
		system.assertEquals(null, con.mailingcity);
		system.assertEquals(date.newinstance(1999,9,9), con.birthdate);

		// account parsing
		acct = (account)(updateSObjectFromJSON('account', (sobject)acct, js));
		system.assertEquals('Seattle', acct.billingcity);

		// payment parsing for opp
		opportunity opp = new opportunity(name = 'test opp', closedate = system.today(), stagename = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE);
		opp = (opportunity)(updateSObjectFromJSON('payment', (sobject)opp, js));
		system.assertEquals('Created by our nifty payment website.', opp.description);
	}	

	static testMethod void testMissingInput () {
		GW_OnlinePayment opmt = new GW_OnlinePayment();
		try {
			opmt.processRecurringPayment();
		} catch (exception e) {
			system.assertEquals('OnlinePaymentException', e.getTypeName());
		}
	}
}