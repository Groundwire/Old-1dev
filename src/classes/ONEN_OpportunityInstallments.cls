public class ONEN_OpportunityInstallments {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    public static boolean haveCheckedPayments = false;
    
    public static list<OppPayment__c> GetMirrorPayments ( list<Opportunity> OppsToMirror ) {
    
        list<OppPayment__c> OPToCreate = new list<OppPayment__c>();
    
        for ( Opportunity thisOpp: OppsToMirror ) {
            
            boolean IsWon = thisOpp.IsWon;
            boolean IsPaid = ( IsWon ) ? true : false;
            
            OppPayment__c newInst = new OppPayment__c ( 
                Opportunity__c = thisOpp.Id,
                Amount__c = thisOpp.Amount,
                Date__c = thisOpp.CloseDate,
                Paid__c = IsPaid,
                Check_Number__c = thisOpp.Check_Number__c,
                Check_Date__c = thisOpp.Check_Date__c
            );
            OPToCreate.add (newInst);
        }
        
        return OPToCreate;
        
    }
    
    public static void updateMirrorPayments (map<id,Opportunity> OppsToUpdateMap) {
        // get the mirror payments that exist (by exclusind those w/ Installment flag set)
        // if that flag is set, it's an installment & we don't want to touch it 
        OppPayment__c[] OppPayments = [SELECT id, Opportunity__r.Check_Number__c, Opportunity__r.Check_Date__c, Opportunity__r.Amount,
                                       Opportunity__r.CloseDate, Opportunity__r.IsWon,
                                       IsInstallment__c FROM OppPayment__c WHERE IsInstallment__c = false AND Opportunity__c 
                                       IN :OppsToUpdateMap.keyset() ];
            
        if ( OppPayments.size() > 0 ) {
        
            // for the mirror payments we found, update the fields to keep in sync between opp and payment
            for ( OppPayment__c thisPaymt : OppPayments ) {
                // system.debug ('paymt before update: ' + thisInst);
                thisPaymt.Paid__c = ( thisPaymt.Opportunity__r.IsWon && !thisPaymt.IsInstallment__c) ? true : false;
                thisPaymt.Check_Number__c = thisPaymt.Opportunity__r.Check_Number__c;
                thisPaymt.Check_Date__c = thisPaymt.Opportunity__r.Check_Date__c;
                thisPaymt.Amount__c = thisPaymt.Opportunity__r.Amount;
                thisPaymt.Date__c = thisPaymt.Opportunity__r.CloseDate;
                //system.debug ('paymt after update: ' + thisInst);
            }
        
            update OppPayments;
        }
        haveCheckedPayments = true; 
    }
    
    /* TESTS */
    
    private static string MbrRectype = ONEN_Constants.OPP_MEMBER_RECTYPE_FORTESTS;
    private static string GiftRectype = ONEN_Constants.OPP_NONMEMBER_RECTYPE_FORTESTS;
     
    static testMethod void testMirrorPaymentCreate () {
      
        Date datToday = System.Today();
        Date datClose = datToday;
           
        // create & insert Account
        Account[] TestAccts = ONEN_UnitTestData.CreateMultipleTestAccounts(1) ;
        insert TestAccts;
          
        Account Acct1 = TestAccts[0];
          
        // create & insert grant opp
        Opportunity[] TestOpps = ONEN_UnitTestData.OppsForAccountList (TestAccts, null, ONEN_Constants.OPP_DEFAULT_STAGE, datClose, 1000, GiftRectype);
        insert TestOpps;
          
        Opportunity Opp1 = TestOpps[0];
          
        // test that a mirror payment was created
        OppPayment__c[] mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
          
        OppPayment__c OP1 = mirrorOPs[0];
        System.AssertEquals ( 1000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( false , OP1.Paid__c);
          
        // now chg the amt of the opp, test that mirror chgs too
        system.debug ('TEST>>>> chging Amount of Opp..');
        Opp1.Amount = 2000;
        update Opp1;
          
        mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
          
        OP1 = mirrorOPs[0];
        System.AssertEquals ( 2000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
          
        // now chg opp to ClosedWon, make sure mirror goes to Paid
        system.debug ('TEST>>>> chging Opp to ClosedWon..');
        system.debug ('TEST>>>> Paymt before chg: ' + OP1);
        Opp1.StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE;
        update Opp1;
          
        mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
          
        OP1 = mirrorOPs[0];
        system.debug ('TEST>>>> Paymt after chg: ' + OP1);
        
        System.AssertEquals ( 2000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( true , OP1.Paid__c);
          
        // now delete the Payment, trigger should create a new mirror
        delete mirrorOPs;
          
        mirrorOPs = [SELECT id, Opportunity__c, IsInstallment__c, Amount__c, Date__c, Paid__c FROM OppPayment__c WHERE Opportunity__c = :Opp1.id];
          
        System.AssertEquals ( 1 , mirrorOPs.size() );
        OP1 = mirrorOPs[0];
        System.AssertEquals ( 2000, OP1.Amount__c);
        System.AssertEquals ( Opp1.CloseDate, OP1.Date__c);
        System.AssertEquals ( false , OP1.IsInstallment__c);
        System.AssertEquals ( true , OP1.Paid__c);
          
    }
     
}