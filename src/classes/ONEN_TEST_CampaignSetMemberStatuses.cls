// Written by David Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU General Public License. http://www.gnu.org/licenses/


@isTest 
private class ONEN_TEST_CampaignSetMemberStatuses {

/* 
DEPRECATED 12.1.09 MS
These tests moved to the CampaignMemberStatus class

    static void setDefaultSettings() {
        ONEN_DefaultCampaignStatusSettings__c settings = ONEN_DefaultCampaignStatusSettings__c.getOrgDefaults();
        settings.Campaign_Type_Subtype_1__c = 'Communication;Email';
        settings.Campaign_Statuses_1__c = 'Opened;y;n\nClicked;y;n\nUnsubscribed;n;n\nBounced;n;n';
        settings.Campaign_Type_Subtype_2__c = 'Appeal;';
        settings.Campaign_Statuses_2__c = 'Donated;y;n';
        settings.Campaign_Type_Subtype_3__c = 'Event;';
        settings.Campaign_Statuses_3__c = 'Invited;n;y\nAttended;y;n';
        settings.Campaign_Type_Subtype_4__c = null;
        settings.Campaign_Statuses_4__c = null;
        settings.Campaign_Type_Subtype_5__c = null;
        settings.Campaign_Statuses_5__c = null;
        update settings;
    }


    public static testMethod void testEmailStatuses() {
        
        setDefaultSettings();
        
        //create a campaign that WON'T trip the trigger to ensure that all of the statuses
        //exist in the CampaignMemberStatus table -- to prevent test errors when statuses don't
        //already exist in production.
        Campaign newCampaign = new Campaign (
            Name = 'Bogus_Campaign'             
        );
        insert newCampaign;
        
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        CampaignMemberStatus statusOne = new CampaignMemberStatus(
                Label = 'Opened',
                CampaignId = newCampaign.id,
                HasResponded = true,
                SortOrder = 7
        );
        newStatuses.add(statusOne);     

        CampaignMemberStatus statusTwo = new CampaignMemberStatus(
            Label = 'Clicked',
            CampaignId = newCampaign.id,
            HasResponded = true,
            SortOrder = 8
        );
        newStatuses.add(statusTwo);     

        CampaignMemberStatus statusThree = new CampaignMemberStatus(
            Label = 'Unsubscribed',
            CampaignId = newCampaign.id,
            HasResponded = true,
            SortOrder = 9
        );
        newStatuses.add(statusThree);
        
        CampaignMemberStatus statusFour = new CampaignMemberStatus(
            Label = 'Bounced',
            CampaignId = newCampaign.id,
            HasResponded = true,
            SortOrder = 10
        );
        newStatuses.add(statusFour);
        
        if ( newStatuses.size() > 0 ) {
            insert newStatuses;
        }
        
        // Insert a new campaign with CampaignSub-Type 'Email' to test the trigger
        // TBD these tests should set settings so doesn't rely on user settings
        Campaign newCampaign1 = new Campaign (
            Name = 'New Campaign',
            Campaign_Type__c = 'Communication',
            Campaign_Sub_Type__c = 'Email'              
        );
    
        insert newCampaign1;
    
        // Verify that the new Campaign Member Status 'Opened' has been created
        CampaignMemberStatus newStatusOne = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Opened' limit 1];
        System.assertEquals('Opened', newStatusOne.Label);
        
        // Verify that the new Campaign Member Status 'Clicked' has been created
        CampaignMemberStatus newStatusTwo = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Clicked' limit 1];
        System.assertEquals('Clicked', newStatusTwo.Label);
        
        // Verify that the new Campaign Member Status 'Unsubscribed' has been created
        CampaignMemberStatus newStatusThree = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Unsubscribed' limit 1];
        System.assertEquals('Unsubscribed', newStatusThree.Label);
        
        // Verify that the new Campaign Member Status 'Unsubscribed' has been created
        CampaignMemberStatus newStatusFour = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign1.id and Label = 'Bounced' limit 1];
        System.assertEquals('Bounced', newStatusFour.Label);
    }
    
    public static testMethod void testAppealStatuses() {

        setDefaultSettings();
        
        //create a campaign that WON'T trip the trigger to ensure that all of the statuses
        //exist in the CampaignMemberStatus table -- to prevent test errors when statuses don't
        //already exist in production.
        Campaign newCampaign = new Campaign (
            Name = 'Bogus_Campaign'             
        );
        insert newCampaign;
        
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        CampaignMemberStatus statusFive = new CampaignMemberStatus(
                Label = 'Donated',
                CampaignId = newCampaign.id,
                HasResponded = true,
                SortOrder = 11
            );
            newStatuses.add(statusFive);
        
        if ( newStatuses.size() > 0 ) {
            insert newStatuses;
        }
        
        // Insert a new campaign with Campaign Type 'Appeal' to test
        Campaign newCampaign2 = new Campaign (
            Name = 'New Campaign',
            Campaign_Type__c = 'Appeal'             
        );
    
        insert newCampaign2;
    
        // Verify that the new Campaign Member Status 'Donated' has been created
        CampaignMemberStatus newStatusFive = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign2.id and Label = 'Donated' limit 1];
        System.assertEquals('Donated', newStatusFive.Label);
        
    }
    
    public static testMethod void testEventStatuses() {

        setDefaultSettings();
        
        //create a campaign that WON'T trip the trigger to ensure that all of the statuses
        //exist in the CampaignMemberStatus table -- to prevent test errors when statuses don't
        //already exist in production.
        Campaign newCampaign = new Campaign (
            Name = 'Bogus_Campaign'             
        );
        insert newCampaign;
        
        List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
        CampaignMemberStatus statusSix = new CampaignMemberStatus(
                Label = 'Invited',
                CampaignId = newCampaign.id,
                HasResponded = false,
                SortOrder = 12
        );
        newStatuses.add(statusSix);
        
        CampaignMemberStatus statusSeven = new CampaignMemberStatus(
            Label = 'Attended',
            CampaignId = newCampaign.id,
            HasResponded = true,
            SortOrder = 13
        );
        newStatuses.add(statusSeven);
        
        if ( newStatuses.size() > 0 ) {
            insert newStatuses;
        }
        
        // Insert a new campaign with Campaign Type 'Appeal' to test
        Campaign newCampaign3 = new Campaign (
            Name = 'New Campaign',
            Campaign_Type__c = 'Event'              
        );
    
        insert newCampaign3;
    
        // Verify that the new Campaign Member Status 'Invited' has been created
        CampaignMemberStatus newStatusSix = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign3.id and Label = 'Invited' limit 1];
        System.assertEquals('Invited', newStatusSix.Label);
        
        // Verify that the new Campaign Member Status 'Attended' has been created
        CampaignMemberStatus newStatusSeven = [select CampaignId, Label from CampaignMemberStatus where CampaignId = :newCampaign3.id and Label = 'Attended' limit 1];
        System.assertEquals('Attended', newStatusSeven.Label);
        
    }
*/  
    
}