@isTest 
private class ONEN_TEST_LeadToCampaign {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	/*********************************************************************************
	* Test creation of a lead and connection to a campaign
	*********************************************************************************/
	public static testMethod void testLeadOnCampaignNoStatus() {
		
		Campaign firstCampaign = new Campaign (
			Name='testcampaign'			
		);

		insert firstCampaign;
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Campaign_Id__c=firstCampaign.id	
		);

		insert firstLead;
		system.debug('firstLead.Id: ' + firstLead.Id);
		CampaignMember[] firstCampaginMember = [select id,leadid,status from CampaignMember where CampaignId =:firstCampaign.id and LeadId=:firstLead.Id];
		system.debug('firstcampaignmember: ' + firstCampaginMember);
		system.assertequals(1,firstCampaginMember.size());
	}
	
	public static testMethod void testLeadOnCampaignValidStatus() {
		
		Campaign firstCampaign = new Campaign (
			Name='testcampaign'			
		);

		insert firstCampaign;
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Campaign_Id__c=firstCampaign.id,
			Campaign_Member_Status__c='Responded'	
		);

		insert firstLead;
		//system.debug('firstLead.Id: ' + firstLead.Id);
		CampaignMember[] firstCampaginMember = [select id,leadid,status from CampaignMember where CampaignId =:firstCampaign.id and LeadId=:firstLead.Id];
		//system.debug('firstcampaignmember: ' + firstCampaginMember);
		system.assertequals(1,firstCampaginMember.size());
	}
	
	public static testMethod void testLeadOnCampaignInValidStatus() {
		
		Campaign firstCampaign = new Campaign (
			Name='testcampaign'			
		);

		insert firstCampaign;
		
		Lead firstLead = new Lead (
			FirstName='Joe',
			LastName='Johanssen',
			Company='[Not Provided]',
			Campaign_Id__c=firstCampaign.id,
			Campaign_Member_Status__c='NeverHeardOfHim'	
		);

		insert firstLead;
		//system.debug('firstLead.Id: ' + firstLead.Id);
		CampaignMember[] firstCampaginMember = [select id,leadid,status from CampaignMember where CampaignId =:firstCampaign.id and LeadId=:firstLead.Id];
		//system.debug('firstcampaignmember: ' + firstCampaginMember);
		system.assertequals(1,firstCampaginMember.size());
	} 
}