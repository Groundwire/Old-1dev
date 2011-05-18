trigger ONEN_Campaign_SetMemberStatuses on Campaign (after insert) {
// Written by Steve Andersen, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	ONEN_CampaignMemberStatus.addDefaultStatuses (trigger.new);
}