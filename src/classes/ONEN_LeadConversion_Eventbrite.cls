public class ONEN_LeadConversion_Eventbrite extends ONEN_LeadConversion {
// to support eventbrite, use this class in the lead converter controller instead of the usual one
// Written by Evan Callahan, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public ONEN_LeadConversion_Eventbrite(integer leadLimit) {
		super(leadLimit);
	}
	
	public override void customOppProcessing (map<id, Opportunity> newOpps, map<id, Opportunity> oppFixes, map<id, contact> cMap, list<Database.leadConvertResult> lcrs) {

		// look for eventbrite data to populate in these opps
		GW_EventbriteOpportunities EO = new GW_EventbriteOpportunities();  
		EO.fillEventbriteOppDetails( newOpps, lcrs );
		EO.fillEventbriteOppDetails( oppFixes, lcrs );

		system.debug('EB custom opp processing');
		system.debug(newOpps);
		system.debug(oppFixes); 
	}
}