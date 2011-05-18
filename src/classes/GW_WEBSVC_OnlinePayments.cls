global class GW_WEBSVC_OnlinePayments {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101 
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* Webservice version of the GW_OnlinePayments interface
* Use this class to insert online payments from a website
-----------------------------------------------------------------------------------------------*/	

	// instantiate the Groundwire online payments class
	static GW_OnlinePayment gwop = new GW_OnlinePayment();
	
	// array structure to store each item
	global class Item {
		WebService string name; 
		WebService string code;
		WebService integer quantity;
		WebService decimal amount;
	}

	// data structure to pass in and return payment data
	global class PaymentInfo {

		// payer data
		WebService string payerId;
		WebService string email;
		WebService string firstName;
		WebService string lastName;
		WebService string companyName;
		WebService string street;
		WebService string city;
		WebService string state;
		WebService string zip;
		WebService string country;
		WebService string phone;
		WebService boolean companyIsPayer;		// if both contact and account are set, this determines 
												// whether opp should be org or individual
														
		// payment data
		WebService OnlinePayment.Processor pmtProcessor;
		WebService OnlinePayment.PaymentType pmtType;
	 	WebService OnlinePayment.PaymentStatus pmtStatus;
		WebService string txnId;
		WebService string parentTxnId;   // for refund or reversal
		WebService string cardType;
		WebService string last4digits;
		WebService string currencyCode;
		WebService decimal exchangeRate;
		WebService decimal totalAmount;
		WebService decimal fee;
		WebService decimal tax;
		WebService decimal shipping;
		WebService list<Item> itemList;
		WebService string invoice;
		WebService string reasonCode;
		WebService string memo; 
	
		// use the custom field to pass additional details you need, such as the campaign for the opportunity
		// one creative idea is to pass JSON in this property to set any custom fields in Salesforce
		WebService string custom;
	
		// properties for recurring payment or subscription
		WebService string recurringTxnId;  
		WebService OnlinePayment.RecurringPeriod pmtPeriod;
		WebService integer frequency;			// combine with period above, e.g. every 1 Month
		WebService integer occurrences;
		WebService date startDate;
	
		// you can set these to existing objects, or use the setPayer method to match or create the payer
		WebService id contactId;
		WebService id accountId;
	
		// after a successful call to one of the methods, this will be set to the associated opportunity
		WebService id opportunityId;
	
		// contains a code indicating the result of trying to match to a contact or account
		WebService OnlinePayment.MatchResult payerMatchResult;
	}

	// METHODS FOR PROCESSING PAYMENTS

	// calling setPayer is always optional, becuase the other methods will each call it
	// it is exposed so that you can run separately and see the result if you need to
	WebService static boolean setPayer( PaymentInfo payment ) {
		setProps( payment );
		boolean res = gwop.setPayer();
		getProps( payment );
		return res;
	}	

	WebService static boolean processSinglePayment( PaymentInfo payment ) {
		setProps( payment );
		boolean res = gwop.processSinglePayment();
		getProps( payment );
		return res;
	}

	WebService static boolean startRecurringPayments( PaymentInfo payment ) {
		setProps( payment );
		boolean res = gwop.startRecurringPayments();
		getProps( payment );
		return res;
	}	
	
	WebService static boolean processRecurringPayment( PaymentInfo payment ) {
		setProps( payment );
		boolean res = gwop.processRecurringPayment();
		getProps( payment );
		return res;
	}

	WebService static boolean cancelRecurringPayments( PaymentInfo payment ) {
		setProps( payment );
		boolean res = gwop.cancelRecurringPayments();
		getProps( payment );
		return res;
	}

	// method that sets the webservice properties on the online payment class
	global static void setProps( PaymentInfo payment ) {
		gwop.payerId = payment.payerId;
		gwop.email = payment.email;
		gwop.firstName = payment.firstName;
		gwop.lastName = payment.lastName;
		gwop.companyName = payment.companyName;
		gwop.street = payment.street;
		gwop.city = payment.city;
		gwop.state = payment.state;
		gwop.zip = payment.zip;
		gwop.country = payment.country;
		gwop.phone = payment.phone;
		if (gwop.companyIsPayer == null) gwop.companyIsPayer = payment.companyIsPayer;
		
		gwop.pmtProcessor = payment.pmtProcessor;
		gwop.pmtType = payment.pmtType;
 		gwop.pmtStatus = payment.pmtStatus; 
		gwop.txnId = payment.txnId;
		gwop.parentTxnId = payment.parentTxnId;  // for refund or reversal
		gwop.cardType = payment.cardType;
		gwop.last4digits = payment.last4digits;
		gwop.currencyCode = payment.currencyCode;
		gwop.exchangeRate = payment.exchangeRate;
		gwop.totalAmount = payment.totalAmount;
		gwop.fee = payment.fee;
		gwop.tax = payment.tax; 
		gwop.shipping = payment.shipping;
		gwop.invoice = payment.invoice;
		gwop.reasonCode = payment.reasonCode;
		gwop.memo = payment.memo;  
		if (gwop.itemList.isEmpty() && payment.itemList != null) {
			for (Item itm : payment.itemList)
				gwop.itemList.add(new OnlinePayment.Item( 
					itm.Name, 
					itm.code, 
					itm.quantity, 
					itm.amount )
				);
		} 
		gwop.custom = payment.custom;
		gwop.recurringTxnId = payment.recurringTxnId;
		gwop.pmtPeriod = payment.pmtPeriod;
		gwop.frequency = payment.frequency;		// combine with period above, e.g. every 1 Month
		gwop.occurrences = payment.occurrences;
		gwop.startDate = payment.startDate;
		if (gwop.contactId == null) gwop.contactId = payment.contactId;
		if (gwop.accountId == null) gwop.accountId = payment.accountId;		
	}
	
	// methods that get back properties from the class
	global static void getProps( PaymentInfo payment ) {
		payment.payerId = gwop.payerId;
		payment.companyIsPayer = gwop.companyIsPayer;
		payment.payerMatchResult = gwop.payerMatchResult;	
		payment.txnId = gwop.txnId;
		payment.parentTxnId = gwop.parentTxnId;
		payment.recurringTxnId = gwop.recurringTxnId;  
		payment.contactId = gwop.contactId;
		payment.accountId = gwop.accountId;		
		payment.opportunityId = gwop.opportunityId;		
	}

	// TESTS
	static testMethod void testSetPayer() {
		GW_WEBSVC_OnlinePayments.PaymentInfo p = new GW_WEBSVC_OnlinePayments.paymentInfo();
		p.firstname = 'EvanTest';
		p.lastname = 'CallahanTest';
		p.email = 'evantest@groundwiretest.org';
		boolean s = GW_WEBSVC_OnlinePayments.setPayer( p );
		system.assert(s, 'setPayer returned fail');
		system.assertEquals(OnlinePayment.MatchResult.NEW_CONTACT, p.payerMatchResult);	
	}

	static testMethod void testSinglePayment() {
		insert new Contact(firstName = 'EvanTest', lastName = 'CallahanTest', 
			email = 'evantest@groundwiretest.org');
		
		test.startTest();
		
		GW_WEBSVC_OnlinePayments.PaymentInfo p = new GW_WEBSVC_OnlinePayments.PaymentInfo();
		p.firstname = 'EvanTest';
		p.lastname = 'CallahanTest';
		p.email = 'evantest@groundwiretest.org';
		p.txnId = 'X0X0X';
		p.totalAmount = 1234;
		
		GW_WEBSVC_OnlinePayments.Item i = new GW_WEBSVC_OnlinePayments.Item();
		i.name = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
		i.amount = 1234;
		p.itemList = new list<GW_WEBSVC_OnlinePayments.Item>{ i };
		
		boolean s = GW_WEBSVC_OnlinePayments.processSinglePayment( p );
		system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, p.payerMatchResult);	
		system.assert(s, 'processSinglePayment returned fail');
		
		// look for the opp
		oppPayment__c[] op0 = [select id, paid__c, amount__c, isinstallment__c from oppPayment__c 
			where opportunity__r.Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(1, op0.size(), 'no opp with the specified txnid');			
	}

	static testMethod void testRecurring() {
		insert new Contact(firstName = 'EvanTest', lastName = 'CallahanTest', 
			email = 'evantest@groundwiretest.org');
		
		test.startTest();
		
		GW_WEBSVC_OnlinePayments.PaymentInfo p = new GW_WEBSVC_OnlinePayments.PaymentInfo();
		p.firstname = 'EvanTest';
		p.lastname = 'CallahanTest';
		p.email = 'evantest@groundwiretest.org';
		p.txnId = 'X0X0X';
		p.totalAmount = 1234;
		p.pmtPeriod = OnlinePayment.RecurringPeriod.MONTH;
		p.frequency = 1;
		p.recurringTxnId = 'Y0Y0Y';
		p.phone = '(123) 555-1212';
		
		GW_WEBSVC_OnlinePayments.Item i = new GW_WEBSVC_OnlinePayments.Item();
		i.name = ONEN_Constants.OPP_DEFAULT_RECTYPE_FORTESTS;
		i.amount = 1234;
		p.itemList = new list<GW_WEBSVC_OnlinePayments.Item>{ i };
		
		// set up the payments
		boolean s = GW_WEBSVC_OnlinePayments.startRecurringPayments( p );
		system.assert(s, 'startRecurringPayments returned fail');
		
		string rtid = p.recurringTxnId;
		system.assert(rtid != null, 'No recurring txn id.');

		// look for the payment
		oppPayment__c[] op0 = [select id, paid__c, amount__c, isinstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assert(op0.size() > 0, 'no payments found');			
		system.assertEquals(false, op0[0].paid__c, 'paid is set when it should not be');			
		
		// log an authorized payment
		p.pmtStatus = OnlinePayment.PaymentStatus.AUTHORIZED;
		s = GW_WEBSVC_OnlinePayments.processRecurringPayment( p );
		system.assert(s, 'processRecurringPayment returned fail on create/authorize');
		
		// look for the payment
		oppPayment__c[] op2 = [select id, paid__c, amount__c, isinstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(false, op2[0].paid__c, 'paid is set when it should not be');			
		
		// log actual payment success
		p.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		s = GW_WEBSVC_OnlinePayments.processRecurringPayment( p );
		system.assert(s, 'processRecurringPayment returned fail on fulfilled payment');
		
		// look for the payment
		oppPayment__c[] op3 = [select id, paid__c, amount__c, isinstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' order by date__c];
		system.assertEquals(true, op3[0].paid__c, 'paid is not set properly');			

		// cancel the rest
		s = GW_WEBSVC_OnlinePayments.cancelRecurringPayments( p );
		system.assert(s, 'cancelRecurringPayments returned fail');
		// look for the payment
		oppPayment__c[] op4 = [select id, paid__c, amount__c, isinstallment__c from oppPayment__c 
			where opportunity__r.recurring_payment__r.Transaction_Id__c = 'Y0Y0Y' and paid__c = false];
		system.assertEquals(0, op4.size(), 'unpaid payments exist on canceled subscr');		
	}
}