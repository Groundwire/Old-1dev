trigger ONEN_Contact_EngagementLvlOverride on Contact (before insert, before update) {
// Written by Matthew Scholtz, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	// when engagement lvl override gets set, apply the default time limit unless user has specified otherwise
	// can't do this w/ workflow due to limitations in date arithmetic
	
	Contact[] cons = new Contact[0];
	EngagementLadderSettings__c settings = EngagementLadderSettings__c.getOrgDefaults();
	integer months = 12;  // overall default if none other specified
	if (settings!=null) months = (settings.Override_Default_Duration__c==null) ? months : settings.Override_Default_Duration__c.intvalue();
	
	date defDate;
	
	for (Contact con : trigger.new) {
		if (con.Engagement_Level_Override__c!=null) {
			Contact oldCon;
			boolean dateChgd = false;
			boolean lvlChgd = false;
			if (trigger.isUpdate) {
				oldCon = trigger.oldMap.get(con.Id);
				dateChgd = (con.Engagement_Override_End_Date__c!=oldCon.Engagement_Override_End_Date__c ? true : false );
				lvlChgd = (con.Engagement_Level_Override__c!=oldCon.Engagement_Level_Override__c ? true : false );
			}
			if ( (trigger.isInsert && con.Engagement_Override_End_Date__c==null) || (trigger.isUpdate && lvlChgd && !dateChgd) ) {
				cons.add(con);
			}			

		}		  
	}
	
	if (cons.size() > 0) {
		// optimization: do date math after first loop
		defDate = system.today().addMonths(months);
		for (Contact con:cons) {
			con.Engagement_Override_End_Date__c = defDate;
		}
	}
	
}