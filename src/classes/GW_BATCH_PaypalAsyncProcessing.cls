// batch apex class to process paypal payment notifications later (via scheduled apex) 
// Written by David Habib, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

global class GW_BATCH_PaypalAsyncProcessing implements Database.Batchable<SObject>, Schedulable {

	public String query { get; set; }

	// constructors
	public GW_BATCH_PaypalAsyncProcessing() {
		system.debug(LoggingLevel.INFO, 'creating a new PayPal batch class.');
		query = 'SELECT id, Transaction_Type__c, Transaction_Id__c, Recurring_Transaction_Id__c, ' +
				'Parent_Transaction_Id__c, Item_Name__c, Item_Number__c, Payer_Email__c, IsProcessed__c, ' +
         		'Payer_ID__c, Payment_Amount__c, Payment_Status__c, Parameters__c, Processing_Error__c from Payment_Notification__c ' + 
                'WHERE IsProcessed__c = false AND IsTest__c = false AND transaction_type__c != null ' +
                'AND Payment_Status__c != \'Error\' AND Payment_Status__c != \'Declined\' ' +
                'ORDER BY transaction_type__c DESC ';        
	}
	
	public GW_BATCH_PaypalAsyncProcessing(string q) { 
		query = q; 
	}

	global database.Querylocator start(Database.BatchableContext bc) {
		system.debug(LoggingLevel.INFO, 'start call on GW_BATCH_PaypalAsyncProcessing');
		return Database.getQueryLocator(query);		 
	}

	global void execute(SchedulableContext SC) {		
		system.debug(LoggingLevel.INFO, 'schedule an execute on GW_BATCH_PaypalAsyncProcessing');
		GW_BATCH_PaypalAsyncProcessing batch = new GW_BATCH_PaypalAsyncProcessing();		
		id batchinstanceid = database.executeBatch (batch); // keep our batch size small to avoid too many soql's
	}

	global public void execute(Database.BatchableContext bc, Sobject[] result) {
		system.debug(LoggingLevel.INFO, 'execute call on GW_BATCH_PaypalAsyncProcessing');
		for (SObject sobj : result) {
			//system.assertEquals(false, sobj.get('IsProcessed__c'));
			GW_CTRL_PaypalNotification.ProcessIPN((Payment_Notification__c)sobj, false);
			//system.assertEquals(true, sobj.get('IsProcessed__c')); 
		} 
		
		// update the ipn records
		update result;
	}
	
	global void finish(Database.BatchableContext bc) {
		system.debug(LoggingLevel.INFO, 'finish call on GW_BATCH_PaypalAsyncProcessing');		
		// clear out old notifications
		GW_CTRL_PaypalNotification.deleteOldNotifications();		
	}

// NOTE: No test code, because this class gets full test coverage
// from tests in GW_CTRL_PaypalNotification.cls

}