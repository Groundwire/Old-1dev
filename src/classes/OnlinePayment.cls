public abstract class OnlinePayment {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class provides an interface for processing an online payment, creating an opportunity record. 
* It is intended to be called either from web pages or VF pages that take payments, or from a 
* payment notification listener (such as the GW_CTRL_PaypalNotification class).
*
* This interface is an attempt to support multiple payment processors in a generic way, so
* that we can share payment processing tools for different websites or merchant account providers.
*
* The basic use of the class is that you instantiate it, set all the properties you have (either
* from a notification or a web entry), call a method, and then look at any properties again
-----------------------------------------------------------------------------------------------*/	

	// these enumerations provide abstract support for different payment gateways
	public enum Processor { 
		PAYPAL,
		AUTHNET,
		OTHER
	}
	public enum PaymentStatus { 
		COMPLETED,  	// you have the money
		AUTHORIZED,		// you need to take action
		PENDING, 		// you might need to take action, or just wait
		DECLINED, 		// bad credit, zipcode, or cvs code
		FAILED, 		// previously pending/authorized, but no longer
		REVERSED		// previously completed, money was refunded
	}
	public enum PaymentType { 
		CREDITCARD,
		ECHECK, 
		EFT,			// electronic funds transfer
		INSTANT			// paypal uses this for anything that isn't echeck
	}
	public enum RecurringPeriod { 
		DAY,
		WEEK, 
		MONTH,
		YEAR	
	}
	
	// enumeration of possible results from SetPayer method
	public enum MatchResult { 
		TRANSACTION_MATCH,
		CONTACT_MATCH,
		NEW_CONTACT,
		ACCOUNT_MATCH,
		NEW_ACCOUNT	
	}

	// need a custom exception class so we can throw an error back
	public class OnlinePaymentException extends Exception {}

	// subclass to track one or more items for a payment or order
	public class Item {
		public string name { get; set; } 
		public string code { get; set; }
		public integer quantity { get; set; }
		public decimal amount { get; set; }
		
		// function to add an item
		public Item( string iName, string iCode, integer iQuantity, decimal iAmount ) {
			name = iName;
			code = iCode;
			quantity = iQuantity;
			amount = iAmount;
		}		
	}

	// properties for matching or creating the payer
	public string payerId { get; set; }
	public string email { get; set; }
	public string firstName { get; set; }
	public string lastName { get; set; }
	public string companyName { get; set; }
	public string street { get; set; }
	public string city { get; set; }
	public string state { get; set; }
	public string zip { get; set; }
	public string country { get; set; }
	public string phone { get; set; }
	
	// properties for creating a payment
	public Processor pmtProcessor { get; set; }
	public PaymentType pmtType { get; set; }
 	public PaymentStatus pmtStatus { get; set; }
	public string txnId { get; set; }
	public string parentTxnId { get; set; }   // for refund or reversal
	public string cardType { get; set; }
	public string last4digits { get; set; }
	public string currencyCode { get; set; }
	public decimal exchangeRate { get; set; }
	public decimal totalAmount { get; set; }
	public decimal fee { get; set; }
	public decimal tax { get; set; }
	public decimal shipping { get; set; }
	public list<Item> itemList { get; set; }
	public string invoice { get; set; }
	public string reasonCode { get; set; }
	public string memo { get; set; } 

	// use the custom field to pass additional details you need, such as the campaign for the opportunity
	// one creative idea is to pass JSON in this property to set any custom fields in Salesforce
	public string custom { get; set; }

	// properties for recurring payment or subscription
	public string recurringTxnId { get; set; }  
	public RecurringPeriod pmtPeriod { get; set; }
	public integer frequency { get; set; }			// combine with period above, e.g. every 1 Month
	public integer occurrences { get; set; }
	public date startDate { get; set; }

	// you can set these to existing objects, or use the setPayer method to match or create the payer
	public id contactId { get; set; }
	public id accountId { get; set; }

	// after a successful call to one of the methods, this will be set to the associated opportunity
	public id opportunityId { get; set; }

	// we will either find or create one or both of these before creating opps
	public contact payerContact { get; private set; }
	public account payerAccount { get; private set; }
	public opportunity paymentOpp { get; private set; }

	public boolean companyIsPayer { get; set; }		// if both contact and account are set, this determines 
													// whether opp should be org or individual
													
	// contains a code indicating the result of trying to match to a contact or account
	public MatchResult payerMatchResult { get; private set; }

	/*------------------------------------------------------------------------------------
	* setPayer method
	* tries to match payer data to an existing account or contact
	* if it does not find a match, it creates a new contact (and/or account) for the opp
	* returns true if there is a designated payer one way or another, false for failure;
	*   also sets the payerMatchResult property to indicate what happened
	*
	* you can call this explicitly, but each of the other methods may want to call it
	* as a first step if the opp or payer is not already set, e.g.
	*    if (paymentOpp != null) {
	*		  // update the payment
	*	 } else if (payerContact != null || payerAccount != null || setPayer()) {
	*         // create a new payment
	*    }
	-------------------------------------------------------------------------------------*/	
	abstract boolean setPayer();
		// for an idea of how to implement this, here is a possible outline:
		
		// look for an existing opp or installment with the specified transaction Id and set the acct/con ids based on that
		// check if the contact or account id were prefilled, use them rather than looking for a match
		// query for the payer by email, secondary email, or payerId - an external ID from paypal or authnet (be sure to query for all contact and account fields you need later)
		// if there is an email match, check last name and optionally first name as well to verify match
		// look for a matching account if we do not already have a contact match
		// if we don't have a match, create a payer account or contact; if we do, update the existing account and/or contact with new information provided 
		// if we have a payer, return true

	/*------------------------------------------------------------------------------------
	* processSinglePayment method
	* creates (or updates) an opportunity for an online payment
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	abstract boolean processSinglePayment();
		// make sure we have an opp or payer, or call setPayer
		// if there is already an opp, update it
		// otherwise, create a new opp
		// if successful, set the opp id property and return true

	/*------------------------------------------------------------------------------------
	* startRecurringPayments method
	* creates (or updates) an opportunity for an online recurring payment or subscription
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	abstract boolean startRecurringPayments();	
	
	/*------------------------------------------------------------------------------------
	* processRecurringPayment method
	* creates (or updates) an opportunity for an online payment associated with recurring opp
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	abstract boolean processRecurringPayment();
	
	/*------------------------------------------------------------------------------------
	* cancelRecurringPayments method
	* finds and marks the specified recurring payment opp(s) as closed or written off
	* returns true if the processing was successful
	-------------------------------------------------------------------------------------*/	
	abstract boolean cancelRecurringPayments();
	
}