trigger GW_Opportunity_UpdatePrimaryConRole on Opportunity (after update) {
    
    if (ONEN_OpportunityContactRoles.runPrimaryContactRoleSync) {
        ONEN_OpportunityContactRoles.updatePrimaryOppContactRole(Trigger.oldMap, Trigger.newMap);
    }
     
}