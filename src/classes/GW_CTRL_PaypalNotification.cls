public virtual class GW_CTRL_PaypalNotification {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* Modified by David Habib, copyright (c) 2011 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class provides a "listener" page for Instant Payment Notification (IPN) posts from Paypal.
* When a notification comes in, it logs all the details in a custom object, and then sends them 
*   along for processing in the GW_OnlinePayment class.  If you want to customize how payments 
*   are handled, that class is the place to make changes. 
*
* To make IPN work, you must configure your account properly:
*  - Set up a Sites URL
*  - Set permissions for the sites user to be able to see the page and process notifications
*  - Provide custom settings (Develop | Custom Settings | Online Payment Settings | Manage)
*
* TO DO:
*  provide a mechanism for testing the listener configuration
-----------------------------------------------------------------------------------------------*/	

	// settings object
	public GW_OnlinePaymentSettings__c opSettings;
	
	// what incoming emails are allowed?
	set<string> receiverSet;

	// the parameters paypal is sending us
	map<string,string> params;
	public boolean ipnVerified = false;
	
	// constructor
	public GW_CTRL_PaypalNotification() {
		
		// get settings	- there are defaults for most of them if it isn't set
		opSettings = GW_OnlinePaymentSettings__c.getInstance();
		if (opSettings == null) opSettings = defaultSettings();

		// grab all the stuff paypal sent us
 		params = ApexPages.currentPage().getParameters();

		// make sure this really is a post from Paypal
		if (params.containsKey('txn_type')) {

			// read all post params from PayPal system and add 'cmd' parameter
			String str = '?cmd=_notify-validate';
			for ( string paramName : params.keySet() ) {
				str += '&' + paramName + '=' + EncodingUtil.urlEncode(params.get(paramName), 'UTF-8');			
			}
			
			// choose the right endpoint to post to
			string endpt = (params.get('test_ipn')=='1') ? 
				'https://www.sandbox.paypal.com/cgi-bin/webscr' : 
				'https://www.paypal.com/cgi-bin/webscr'; 
			
			// post back to PayPal system to validate
			system.debug(logginglevel.INFO, 'Verifying IPN with Paypal...');
			HttpRequest req = new HttpRequest(); 
			req.setEndpoint(endpt + str);
			req.setMethod('POST');
			req.setHeader('Content-Type','application/x-www-form-urlencoded');
			Http http = new Http(); 
			HttpResponse resp = execute(req);
			ipnVerified = ( getResponseBody(resp) == 'VERIFIED' );
			
			system.debug(logginglevel.INFO, 
				((ipnVerified) ? '' : ('Request: ' + req.getEndpoint() + '\n')) + 
				'Response: ' + resp.toString());
			
			// look for allowed paypal email names
			if (opSettings.Paypal_Receiver_Email__c != null && opSettings.Paypal_Receiver_Email__c != '') {
				receiverSet = new set<string>(opSettings.Paypal_Receiver_Email__c.split(';'));
			}		
		} else {
			system.debug(logginglevel.INFO, 'Page request did not include txn_type parameter.');
			apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
				'This page receives and responds to payment notification posts from Paypal. ' +
				'To use it, set your Paypal IPN address to the public URL of this page.'));
		}
	}

	// method to initialize settings when they don't exist, or in tests
	static GW_OnlinePaymentSettings__c defaultSettings() {
		GW_OnlinePaymentSettings__c ops = new GW_OnlinePaymentSettings__c();
		ops.Process_Test_Payments__c = true;
		ops.Delete_After_N_Months__c = 12;
		ops.Paypal_Receiver_Email__c = null;   // allow any receiver email
		return ops;
	}

	// the main worker routine which is called from the Visualforce page to handle the IPN
	// it will extract the url parameters, construct a Payment_Notification record,
	// save it to the database, and then schedule a batch job to actually do the work.
	public PageReference processNotification() {
		
		if (ipnVerified) {
			
			// assign key posted parameters to local variables
			String txnType = params.get('txn_type');
			String txnId = params.get('txn_id');
			String recurringTxnId = (params.containsKey('recurring_payment_id')) ? 
				params.get('recurring_payment_id') : params.get('subscr_id');
			String parentTxnId = params.get('parent_txn_id');
			String paymentStatus = params.get('payment_status');
			String itemName = params.get('item_name');
			if (itemName == null) itemName = params.get('product_name');
			String itemNumber = params.get('item_number');			
			String payerEmail = params.get('payer_email');
			String payerId = params.get('payer_id');
			String receiverEmail = params.get('receiver_email');
			boolean ipnTest = (params.get('test_ipn')=='1');

			// amount can be in one of many fields
			decimal paymentAmount;
			if (params.containsKey('mc_gross')) 
				paymentAmount = decimal.valueOf(params.get('mc_gross'));
			else if (params.containsKey('mc_amount3')) 
				paymentAmount = decimal.valueOf(params.get('mc_amount3'));
			else if (params.containsKey('amount3')) 
				paymentAmount = decimal.valueOf(params.get('amount3'));
			else if (params.containsKey('amount')) 
				paymentAmount = decimal.valueOf(params.get('amount'));
			else if (params.containsKey('payment_amount')) 
				paymentAmount = decimal.valueOf(params.get('payment_amount'));
			else if (params.containsKey('amount_per_cycle')) 
				paymentAmount = decimal.valueOf(params.get('amount_per_cycle'));
			else if (params.containsKey('auth_amount')) 
				paymentAmount = decimal.valueOf(params.get('auth_amount'));
			
			// create a payment record for the log
			Payment_Notification__c ipn = new Payment_Notification__c (
				Name = 'Paypal IPN - ' + txnType + ' from ' + payerEmail,
				Transaction_Type__c = txnType,
				Transaction_Id__c = txnId,
				IsTest__c = ipnTest,
				Item_Name__c = itemName,
				Item_Number__c = itemNumber,
				Parent_Transaction_Id__c = parentTxnId,
				Recurring_Transaction_Id__c = recurringTxnId,
				Payer_Email__c = payerEmail,
				Payer_ID__c = payerId,
				Payment_Amount__c = paymentAmount,
				Payment_Status__c = paymentStatus,
				IsProcessed__c = false
			); 

			// concatenate all params to the long text field
			string allParams = '';
			for ( string paramName : params.keySet() )
				allParams += paramName + ' => ' + params.get(paramName) + '\n';
			ipn.Parameters__c = allParams;

			// test for correct business/payment receiver email before processing
			if (!ipnTest && receiverSet != null && !receiverSet.contains(receiverEmail)) {
				ipn.Processing_Error__c = 'Receiver email in the payment notification does not match the allowed addresses.'; 
			
			// check that this is not a test from the sandbox
			} else if (ipnTest && !opSettings.Process_Test_Payments__c ) {
				return null;
			}
			
			// save the IPN record to be serviced later.
			insert  ipn;
			
			// do to PayPal sending multiple IPN's concurrently for subscription signup and the first payment,
			// we need to process them later from batch, to enforce handling them sequentially.
			if (txnType == 'recurring_payment' || txnType == 'subscr_payment')	{
				futureProcessIPN(ipn);	
			} else {
				ProcessIPN(ipn, true);
			}	

			// done!
			return null;
		}
	
	return null;
	}
	
	// helper routine to determine how many batches are already running or queued
	static boolean BatchesUnderLimit() {
  		AsyncApexJob[] batchInProgress = [select id from AsyncApexJob where (status = 'Queued' or status = 'Processing')];
	  	return (batchInProgress.size() < 5 ? true : false);		
	}

	// handler to process the IPN in the future.  
	// it accomplishes this by scheduling our batch job to run in the next minute.
	static void futureProcessIPN(Payment_Notification__c ipn) {
		
		system.debug(LoggingLevel.INFO, 'scheduling Paypal job for ipn');
		system.debug(LoggingLevel.INFO, ipn);

		// we can only schedule up to 5 batches (SF limit), so if
		// we can't schedule any more, just do nothing.  the ipn
		// will get handled by the next scheduled batch.
		if (!BatchesUnderLimit()) {
			system.debug(LoggingLevel.INFO, 'Paypal batch job limit hit. Not scheduling another batch.');
			return;			
		}
		
		// when testing, force the batch to run now
		if (test.isRunningTest()) {
	        GW_BATCH_PaypalAsyncProcessing batch = new GW_BATCH_PaypalAsyncProcessing(); 
			database.executeBatch(batch);			
		} else {
			//Schedule the batch apex to run in 1 minute
	        Datetime sysTime = System.now().addMinutes(1);
	        String chron_exp = '' + sysTime.second() + ' ' + sysTime.minute() + ' ' + sysTime.hour() + ' ' + sysTime.day() + ' ' + sysTime.month() + ' ? ' + sysTime.year();
	        GW_BATCH_PaypalAsyncProcessing batch = new GW_BATCH_PaypalAsyncProcessing(); 
	  		System.schedule('PayPal IPN Async Job ' + sysTime.getTime(), chron_exp, batch);
		}
	}

	// our public routine to actually process the IPN record.
	public static void ProcessIPN(Payment_Notification__c ipn, boolean fUpdateIpn) {
		
		system.debug(LoggingLevel.INFO, 'processing ipn');
		system.debug(LoggingLevel.INFO, ipn);
								
		// recreate page parameters map from our string
		map<string,string> params = new map<string,string>();
		list<string> listPairs = new list<string>(ipn.Parameters__c.split('\n'));
		for (string strPair : listPairs) {
			list<string> listKV = new list<string>(strPair.split(' => '));
			if (listKV.size() == 2) {
				params.put(listKV[0], listKV[1]);
			}
		}			

		// now actually try to do something with the data
		// use try-catch so that we can log the notification even if the processing fails
		try {
			
			// use the generic payment processing class 
			GW_OnlinePayment opmt = new GW_OnlinePayment();
					
			// set all the properties from the notification
			opmt.pmtProcessor = OnlinePayment.Processor.PAYPAL;
			opmt.txnId = ipn.Transaction_Id__c;
			opmt.recurringTxnId = ipn.Recurring_Transaction_Id__c;
			opmt.parentTxnId = ipn.Parent_Transaction_Id__c;
			opmt.payerId = ipn.Payer_ID__c;
			opmt.email = ipn.Payer_Email__c;
			opmt.firstName = params.get('first_name');
			opmt.lastName = params.get('last_name');
			opmt.companyName = params.get('payer_business_name');
			opmt.street = params.get('address_street');
			opmt.city = params.get('address_city');
			opmt.state = params.get('address_state');
			opmt.zip = params.get('address_zip');
			opmt.country = params.get('address_country');
			opmt.phone = params.get('contact_phone');
			opmt.totalAmount = ipn.Payment_Amount__c;
			opmt.currencyCode = params.get('mc_currency');
			if (params.containsKey('exchange_rate')) 
				opmt.exchangeRate = decimal.valueOf(params.get('exchange_rate'));
			if (params.containsKey('mc_fee')) 
				opmt.fee = decimal.valueOf(params.get('mc_fee'));
			if (params.containsKey('tax')) 
				opmt.tax = decimal.valueOf(params.get('tax'));
			if (params.containsKey('mc_shipping')) 
				opmt.shipping = decimal.valueOf(params.get('mc_shipping'));
			opmt.invoice = params.get('invoice');
			opmt.reasonCode = (ipn.Payment_Status__c == 'Pending') ?
				params.get('pending_reason') : params.get('reason_code');
			opmt.custom = params.get('custom');
			opmt.memo = params.get('memo'); 
			if (params.containsKey('recur_times'))
				opmt.occurrences = integer.valueOf(params.get('recur_times'));

			// there may be one or many items
			// add them to the list of Item objects
			if (ipn.Item_Name__c != null || params.containsKey('quantity')) {
				opmt.itemList.add(new OnlinePayment.Item(
					ipn.Item_Name__c,
					ipn.Item_Number__c,
					params.containsKey('quantity') ? integer.valueOf(params.get('quantity')) : null,
					ipn.Payment_Amount__c
				));					
			} else if (params.containsKey('quantity1')) {
				string i = '1';
				while (params.containsKey('quantity' + i)) {
					opmt.itemList.add(new OnlinePayment.Item(
						params.get('item_name' + i),
						params.get('item_number' + i),
						params.containsKey('quantity' + i) ? integer.valueOf(params.get('quantity' + i)) : null,
						params.containsKey('mc_gross_' + i) ? decimal.valueOf(params.get('mc_gross_' + i)) : null
					));	
					i = string.valueOf(integer.valueOf(i) + 1);			
				}
			}
					
			// translate the payment status to the enum value
		 	opmt.pmtStatus = 
		 		(ipn.Payment_Status__c == 'Completed' || ipn.Payment_Status__c == 'Processed' || ipn.Payment_Status__c == 'Canceled_Reversal') ? 
		 			OnlinePayment.PaymentStatus.COMPLETED :
		 		(params.get('pending_reason') == 'authorization') ? OnlinePayment.PaymentStatus.AUTHORIZED :
		 		(ipn.Payment_Status__c == 'Pending') ? OnlinePayment.PaymentStatus.PENDING :
		 		(ipn.Payment_Status__c == 'Failed' || ipn.Payment_Status__c == 'Expired' || ipn.Payment_Status__c == 'Denied' || ipn.Payment_Status__c == 'Voided') ? 
		 			OnlinePayment.PaymentStatus.FAILED :
		 		(ipn.Payment_Status__c == 'Refunded' || ipn.Payment_Status__c == 'Reversed') ? OnlinePayment.PaymentStatus.REVERSED : 
		 		null;
					
			// translate the payment period to the enum value
			string pmtp = params.get('period3');
			if (pmtp != null) {
				opmt.pmtPeriod = 
					(pmtp.contains('Y')) ? OnlinePayment.RecurringPeriod.YEAR :
					(pmtp.contains('M')) ? OnlinePayment.RecurringPeriod.MONTH :
					(pmtp.contains('W')) ? OnlinePayment.RecurringPeriod.WEEK :
					(pmtp.contains('D')) ? OnlinePayment.RecurringPeriod.DAY :
					null;
				pmtp = pmtp.split(' ')[0];
				if (pmtp != null) opmt.frequency = integer.valueOf(pmtp);						
			} else if (params.containsKey('payment_cycle')) {
				opmt.pmtPeriod = 
					(params.get('payment_cycle').startsWith('Y')) ? OnlinePayment.RecurringPeriod.YEAR :
					(params.get('payment_cycle').startsWith('M')) ? OnlinePayment.RecurringPeriod.MONTH :
					(params.get('payment_cycle').startsWith('W')) ? OnlinePayment.RecurringPeriod.WEEK :
					(params.get('payment_cycle').startsWith('D')) ? OnlinePayment.RecurringPeriod.DAY :
					null;
			}

			// translate the payment type to the enum value
			opmt.pmtType = 
				(params.get('payment_type') == 'echeck') ? OnlinePayment.PaymentType.ECHECK :
				(params.get('payment_type') == 'instant') ? OnlinePayment.PaymentType.INSTANT :
				null;  
				// now process each transaction type
			if (ipn.Transaction_Type__c == 'web_accept'		  		// Buy Now, Donation, or Auction Smart Logos button
				 || ipn.Transaction_Type__c == 'cart'				// Multiple items; Express Checkout or the PayPal Shopping Cart
				 || ipn.Transaction_Type__c == 'virtual_terminal'	// Virtual Terminal
				 || ipn.Transaction_Type__c == 'express_checkout'	// Single item vie Express Checkout
				 || ipn.Transaction_Type__c == 'send_money') {		// Send Money tab on the PayPal website	
				
				// process this single payment
				if (opmt.processSinglePayment() && opmt.opportunityId != null) {
					ipn.opportunity__c = opmt.opportunityId;					
					ipn.isProcessed__c = true;
				}
		
			} else if (ipn.Transaction_Type__c == 'subscr_signup'   		// Subscription started
			 			|| ipn.Transaction_Type__c == 'subscr_modify'   	// Subscription modified
			 			|| ipn.Transaction_Type__c == 'recurring_payment_profile_created') {

				// process this subscription/recurring payment profile
				if (opmt.startRecurringPayments() && opmt.opportunityId != null) {
					ipn.opportunity__c = opmt.opportunityId;					
					ipn.isProcessed__c = true;
				}

			} else if (ipn.Transaction_Type__c == 'recurring_payment'   	// Recurring payment received
						|| ipn.Transaction_Type__c == 'subscr_payment')	{	// Subscription payment received
				
				// process this recurring payment
				system.debug('david processreurringpayment');
				if (opmt.processRecurringPayment() && opmt.opportunityId != null) {
					ipn.opportunity__c = opmt.opportunityId;					
					ipn.isProcessed__c = true;
				}
															
			} else if (ipn.Transaction_Type__c == 'subscr_cancel'	   //Subscription canceled
						|| ipn.Transaction_Type__c == 'subscr_eot') {  //Subscription expired

				// process cancellation		
				if (opmt.cancelRecurringPayments()) {											
					ipn.opportunity__c = opmt.opportunityId;					
					ipn.isProcessed__c = true;
				}
						
			//} else if (ipn.Transaction_Type__c == 'subscr_failed') {  //Subscription signup failed
				// could log this person for followup, but probably a waste of time
			
			//} else if (ipn.Transaction_Type__c == 'masspay') {  //Payment sent using MassPay
				// not sure how to deal with this one - all different params than other payments
			
			//} else if (ipn.Transaction_Type__c == 'new_case') {  // A new dispute was filed
				// you could create a case from this
			
			//} else if (ipn.Transaction_Type__c == 'adjustment') {   // A dispute has been resolved and closed
				// you could close a case from this

			} else { 
				ipn.Processing_Error__c = 'The IPN handler does not process this Paypal notification: ' + ipn.Transaction_Type__c; 
			}
				 
		} catch (exception e) {
			system.debug(e);
			ipn.Processing_Error__c = e.getMessage(); 
		}				

		// the ipn is updated by our batch caller if we are told not to.
		if (fUpdateIpn) update ipn;				
	}	
	
	// helper routine called by our batch, to periodically remove old ipn records.	
	public static void deleteOldNotifications() {
		GW_OnlinePaymentSettings__c opSettings = GW_OnlinePaymentSettings__c.getInstance();
		if (opSettings == null) opSettings = defaultSettings();
			
		if (opSettings.Delete_After_N_Months__c != null && opSettings.Delete_After_N_Months__c > 0) {	
			list<Payment_Notification__c> oldPN = 
				[select id from Payment_Notification__c where isProcessed__c = true
					and createddate < : system.today().addmonths(-opSettings.Delete_After_N_Months__c.intValue()) limit 1000];
			if (!oldPN.isEmpty()) delete oldPN;
		}
	}

	// having these two methods separate allows them to be overridden for tests
	protected virtual HttpResponse execute(HttpRequest req) {
		return new http().send(req);
	}
	protected virtual String getResponseBody(HttpResponse r) {
		return r.getBody();
	}

	/*------------------------------------------------------------------------------------
	* TESTS
	-------------------------------------------------------------------------------------*/	

	// this alternate class overrides the main controller so we can test without calling paypal
	private class PaypalNotificationTester extends GW_CTRL_PaypalNotification {
		PaypalNotificationTester() {
		    super();
		}	
        public override String getResponseBody(HttpResponse r) {
			return 'VERIFIED';
		}		
		public override HttpResponse execute(HttpRequest req) {
			HttpResponse r = new HttpResponse();
			return r;
		}
	}
	
	static testMethod void testIPN () {
		
		PageReference pageRef=Page.paypal_notification; 
        Test.setCurrentPage(pageRef); 

		// use the IPN tester class - overrides the real controller class, 
		// but without actual callouts to paypal
		PaypalNotificationTester ppn;
		
		// for code coverage, test opening the page with no params 
		ppn = new PaypalNotificationTester();
		ppn.processNotification();

		// and with a bogus txn type 
		ppn = new PaypalNotificationTester();
        ApexPages.currentPage().getParameters().put('txn_type', 'bogus');
		ppn.processNotification();

		// add params for a realistic incoming IPN
		ppn = new PaypalNotificationTester();
        ApexPages.currentPage().getParameters().put('txn_type', 'web_accept');
        ApexPages.currentPage().getParameters().put('txn_id', 'testing123');
        ApexPages.currentPage().getParameters().put('last_name', 'Jones');
        ApexPages.currentPage().getParameters().put('payer_email', 'donor54321@test.com');
        ApexPages.currentPage().getParameters().put('receiver_email', 'myemail@org.org');
        ApexPages.currentPage().getParameters().put('mc_gross', '1234.56');
        ApexPages.currentPage().getParameters().put('item_name1', 'testitem');
        ApexPages.currentPage().getParameters().put('item_number1', '2222');
        ApexPages.currentPage().getParameters().put('quantity1', '1');
        ApexPages.currentPage().getParameters().put('mc_gross_1', '1234.56');
        ApexPages.currentPage().getParameters().put('exchange_rate', '1');
        ApexPages.currentPage().getParameters().put('mc_fee', '1');
        ApexPages.currentPage().getParameters().put('tax', '1');
        ApexPages.currentPage().getParameters().put('mc_shipping', '1');
		
		// get a ppn tester class - overrides the real controller class
		ppn = new PaypalNotificationTester();

		// process it 
		test.startTest();
		ppn.processNotification();
		
		// delay validation until we can call stopTest to allow the batch to run.
				
		// next test a recurring payment setup
		ppn = new PaypalNotificationTester();
        ApexPages.currentPage().getParameters().put('txn_type', 'subscr_signup');
        ApexPages.currentPage().getParameters().put('last_name', 'Jones');
        ApexPages.currentPage().getParameters().put('payer_email', 'donor999@test.com');
        ApexPages.currentPage().getParameters().put('item_name', 'testitem');
        ApexPages.currentPage().getParameters().put('recurring_payment_id', 'testing123');
        ApexPages.currentPage().getParameters().put('amount3', '1234.56');
        ApexPages.currentPage().getParameters().put('recur_times', '2');
        ApexPages.currentPage().getParameters().put('period3', '1 M');
		
		// get a ppn tester class - overrides the real controller class
		ppn = new PaypalNotificationTester();
		
		// process it
		ppn.processNotification();
		
		// done processing ipn's, so let our batch run!
		test.stopTest();

		// verify first ipn was logged		 
		payment_notification__c ipn;
		ipn = [select name, payment_amount__c, IsProcessed__c from payment_notification__c where 
			payer_email__c = 'donor54321@test.com' limit 1];
		system.assertEquals('Paypal IPN - web_accept from donor54321@test.com', ipn.name);
		system.assertEquals(1234.56, ipn.payment_amount__c);
		system.assertEquals(true, ipn.IsProcessed__c);
		
		// verify second ipn was logged		 
		ipn = [select name, payment_amount__c, IsProcessed__c from payment_notification__c where 
			payer_email__c = 'donor999@test.com' order by createddate desc limit 1];
		system.assertEquals('Paypal IPN - subscr_signup from donor999@test.com', ipn.name);
		system.assertEquals(1234.56, ipn.payment_amount__c);
		system.assertEquals(true, ipn.IsProcessed__c);
		
	}
	
	static testMethod void testManyIPN () {
		
		PageReference pageRef=Page.paypal_notification; 
        Test.setCurrentPage(pageRef); 

		// use the IPN tester class - overrides the real controller class, 
		// but without actual callouts to paypal
		PaypalNotificationTester ppn;
				
		test.startTest();
		integer cIPN = 6; // greater than 6 hit soql limits
		for (integer i = 1; i <= cIPN; i++) {
		
	        ApexPages.currentPage().getParameters().put('txn_type', 'web_accept');
	        ApexPages.currentPage().getParameters().put('txn_id', 'testing123-' + i);
	        ApexPages.currentPage().getParameters().put('first_name', 'MyNameIsIPN');
	        ApexPages.currentPage().getParameters().put('last_name', 'Donor Number ' + i);
	        ApexPages.currentPage().getParameters().put('payer_email', 'donornumber' + i + '@test.com');
	        ApexPages.currentPage().getParameters().put('receiver_email', 'myemail@org.org');
	        ApexPages.currentPage().getParameters().put('mc_gross', '1234.56');
	        ApexPages.currentPage().getParameters().put('item_name1', 'testitem');
	        ApexPages.currentPage().getParameters().put('item_number1', '2222');
	        ApexPages.currentPage().getParameters().put('quantity1', '1');
	        ApexPages.currentPage().getParameters().put('mc_gross_1', '1234.56');
	        ApexPages.currentPage().getParameters().put('exchange_rate', '1');
	        ApexPages.currentPage().getParameters().put('mc_fee', '1');
	        ApexPages.currentPage().getParameters().put('tax', '1');
	        ApexPages.currentPage().getParameters().put('mc_shipping', '1');		
	
			// add params for a realistic incoming IPN
			ppn = new PaypalNotificationTester();
	
			// process it
			ppn.processNotification();
		}

		// done processing ipn's, so let our batch run!
		test.stopTest();

		// validation
		list<Contact> listContact = [select Id, FirstName, LastName from Contact where FirstName = 'MyNameIsIPN'];
		system.debug(listContact);
		system.assertEquals(cIPN, listContact.size());
	}

	static testMethod void testRecurringIPN () {
		
		PageReference pageRef=Page.paypal_notification; 
        Test.setCurrentPage(pageRef); 

		// use the IPN tester class - overrides the real controller class, 
		// but without actual callouts to paypal
		PaypalNotificationTester ppn;
				
		test.startTest();
		integer cIPN = 24; 
		for (integer i = 1; i <= cIPN; i++) {
		
			string txnType = 'subscr_payment';
			if (i == 3) txnType = 'subscr_signup';
			
	        ApexPages.currentPage().getParameters().put('txn_type', txnType);
	        ApexPages.currentPage().getParameters().put('txn_id', 'RecurringTxnId'+i);
	        ApexPages.currentPage().getParameters().put('first_name', 'MyNameIsIPN');
	        ApexPages.currentPage().getParameters().put('last_name', 'Recurring Donor');
	        ApexPages.currentPage().getParameters().put('payer_email', 'recurringdonor@test.com');
	        ApexPages.currentPage().getParameters().put('payer_id', 'ThePayerId');
	        ApexPages.currentPage().getParameters().put('receiver_email', 'myemail@org.org');
	        ApexPages.currentPage().getParameters().put('amount3', '10.00');
	        ApexPages.currentPage().getParameters().put('item_name', 'Donation to Groundwire');
	        ApexPages.currentPage().getParameters().put('item_number1', '2222');
	        ApexPages.currentPage().getParameters().put('quantity1', '1');
	        ApexPages.currentPage().getParameters().put('recur_times', '12');
	        ApexPages.currentPage().getParameters().put('recurring', '1');
	        ApexPages.currentPage().getParameters().put('period3', '1 M');
	        ApexPages.currentPage().getParameters().put('subscr_id', 'TheSubscrId');
	        ApexPages.currentPage().getParameters().put('subscr_date', string.valueOf(system.now()));
	        ApexPages.currentPage().getParameters().put('payment_date', string.valueOf(system.now()));
	        ApexPages.currentPage().getParameters().put('payment_status', 'Completed');
	
	
			// add params for a realistic incoming IPN
			ppn = new PaypalNotificationTester();
	
			// process it
			ppn.processNotification();
		}

		// done processing ipn's, so let our batch run!
		test.stopTest();

		// validation
		list<Contact> listContact = [select Id, FirstName, LastName from Contact where LastName = 'Recurring Donor'];
		system.debug(listContact);
		system.assertEquals(1, listContact.size());
		
		list<Recurring_Payment__c> listRP = [select Id, Amount__c, Contact__c, Frequency__c, Transaction_Id__c 
			From Recurring_Payment__c where Contact__c = :listContact[0].Id];
		system.debug(listRP);
		system.assertEquals(1, listRP.size());		
		
		list<OppPayment__c> listPayment = [select Id, Amount__c, Date__c, Online_Transaction_ID__c, 
			Opportunity__c, Paid__c, opportunity__r.recurring_payment__c from OppPayment__c 
			where opportunity__r.recurring_payment__c = :listRP[0].Id and Paid__c = true]; 
		system.debug(listPayment);
		system.assertEquals(cIPN-1, listPayment.size());
	}
		
}