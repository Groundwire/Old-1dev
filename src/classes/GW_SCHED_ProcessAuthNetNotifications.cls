global class GW_SCHED_ProcessAuthNetNotifications implements Schedulable {

	global void execute(SchedulableContext SC) {
		
		string query = 'SELECT id, Transaction_Type__c, Transaction_Id__c, Recurring_Transaction_Id__c, Item_Name__c, Payer_Email__c,' +          
						'Payer_ID__c, Payment_Amount__c, Payment_Status__c' +
						'FROM Payment_Notification__c' +
						'WHERE IsProcessed__c = false' +
						'AND IsTest__c = false';
		GW_BATCH_AuthnetAsyncProcessing aapBatch = new GW_BATCH_AuthnetAsyncProcessing(query);
		id batchinstanceid = database.executeBatch (aapBatch, 10);  
		
	}

}