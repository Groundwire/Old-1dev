trigger GW_Opportunity_Rollup on Opportunity (after delete, after insert, after undelete, after update) {
// Written by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    // check for the contact roles
    if ( Trigger.isInsert && ONEN_OpportunityContactRoles.haveCheckedContactRoles == false )
        ONEN_OpportunityContactRoles.CheckContactRoles ( trigger.newmap ); 
    if ( Trigger.isUpdate && ONEN_OpportunityInstallments.haveCheckedPayments == false )
        ONEN_OpportunityInstallments.updateMirrorPayments ( trigger.newmap );           
    
    // CALL THE NEW ROLLUP CODE
    GW_OppRollups rg = new GW_OppRollups(); 
    rg.rollupForOppTrigger(trigger.newMap, trigger.oldMap); 
    
}