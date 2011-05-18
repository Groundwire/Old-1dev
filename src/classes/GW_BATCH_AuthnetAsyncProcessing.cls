global class GW_BATCH_AuthnetAsyncProcessing implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
// batch apex class to process authnet payment notifications later (via scheduled apex)
// Written by Evan Callahan, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    public String query { get; set; }

    global set<string> voidTxnIds;
    global set<string> priorAuthTxnIds;

    // constructors
    public GW_BATCH_AuthnetAsyncProcessing() { } 
    public GW_BATCH_AuthnetAsyncProcessing(string q) {  
        query = q; 
    }

    global database.Querylocator start(Database.BatchableContext bc) {
        voidTxnIds = new set<string>();
        priorAuthTxnIds = new set<string>();
        return Database.getQueryLocator(query);      
    }

    global void execute(SchedulableContext SC) {
        
        // check running batches in case there are already 5 running
        AsyncApexJob[] batchInProgress = [select id from AsyncApexJob where (status = 'Queued' or status = 'Processing') and 
            ApexClass.Name = 'GW_BATCH_PaypalAsyncProcessing'];
            
        if (batchInProgress.size() < 5) {
    
            GW_BATCH_AuthnetAsyncProcessing batch = new GW_BATCH_AuthnetAsyncProcessing(
                'SELECT id, Transaction_Type__c, Transaction_Id__c, Recurring_Transaction_Id__c, Item_Name__c, Payer_Email__c, ' +
                    ' Payer_ID__c, Payment_Amount__c, Payment_Status__c, Parameters__c from Payment_Notification__c ' + 
                    ' WHERE IsProcessed__c = false AND IsTest__c = false AND transaction_type__c != null ' +
                    ' AND Payment_Status__c != \'Error\' AND Payment_Status__c != \'Declined\' AND Payment_Status__c != \'Failed\' ' +
                    ' ORDER BY transaction_type__c DESC '        
            );
            id batchinstanceid = database.executeBatch (batch, 10);
        }  
    }

    global public void execute(Database.BatchableContext bc, Sobject[] result) {

        for (sobject o : result) {
                
            Payment_Notification__c ipn = (Payment_Notification__c)o;

            // unpack all params from the long text field
            map<string,string> params = new map<string,string>();
            if (ipn.Parameters__c != null) {
                for ( string paramLine : ipn.Parameters__c.split('\n') ) {
                    list<string> keyAndValue = paramLine.split(' => ');
					if (keyAndValue.size() == 2) params.put(keyAndValue[0], keyAndValue[1]);
                }
            } 

            // now actually try to do something with the data
            string txnId = ipn.transaction_id__c;
            string txnType = ipn.transaction_type__c.toLowerCase();

            if (txnType == 'void')
                voidTxnIds.add(txnId);
                    
            if (txnType == 'prior_auth_capture')
                priorAuthTxnIds.add(txnId);
                
            // if this is already voided, or if it is an auth_only that is also captured,  
            // do nothing but mark the notification record as processed 
            if ((voidTxnIds.contains(txnId) && txnType != 'void') ||
                (priorAuthTxnIds.contains(txnId) && txnType == 'auth_only')) { 
                    
                ipn.isProcessed__c = true;
                    
            } else {
                GW_CTRL_AuthnetNotification processor =  new GW_CTRL_AuthnetNotification(params);
                processor.sendPaymentToProcessor(ipn);
            }
        }
        // log the ipn record
        update result;
    }
    
    global void finish(Database.BatchableContext bc) {
    }

    static string nv(string s) { return ((s==null || s.trim()=='') ? null : s.trim()); } 
}