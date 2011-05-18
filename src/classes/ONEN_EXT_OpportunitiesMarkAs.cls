public class ONEN_EXT_OpportunitiesMarkAs {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public List<Opportunity> selectedOpps;

	public ONEN_EXT_OpportunitiesMarkAs(ApexPages.StandardSetController controller) {
      	this.selectedOpps = (List<Opportunity>)controller.getSelected();
	}
	
	public pageReference MarkAsWon() {
		
		List<Opportunity> OppsToUpdate = new List<Opportunity>();
		for (Opportunity newOpp : selectedOpps) {
			newOpp = new Opportunity (
				id = newOpp.id,
				StageName = ONEN_Constants.OPP_DEFAULT_WON_NOT_THANKED_STAGE
			);
			OppsToUpdate.add(newOpp);
		}
		
		if (OppsToUpdate.size() > 0) {
			update OppsToUpdate;
		}
		PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
		
	}
	
	public pageReference MarkAsLost() {
		
		List<Opportunity> OppsToUpdate = new List<Opportunity>();
		for (Opportunity newOpp : selectedOpps) {
			newOpp = new Opportunity (
				id = newOpp.id,
				StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_LOST_STAGE
			);
			OppsToUpdate.add(newOpp);
		}
		
		if (OppsToUpdate.size() > 0) {
			update OppsToUpdate;
		}
		
		PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
		
	}
	
	public pageReference MarkAsThanked() {
		
		List<Opportunity> OppsToUpdate = new List<Opportunity>();
		for (Opportunity newOpp : selectedOpps) {
			newOpp = new Opportunity (
				id = newOpp.id,
				StageName = ONEN_Constants.OPP_DEFAULT_CLOSED_WON_STAGE
			);
			OppsToUpdate.add(newOpp);
		}
		
		if (OppsToUpdate.size() > 0) {
			update OppsToUpdate;
		}
		
		PageReference p = new PageReference(System.currentPageReference().getParameters().get('retURL'));
        p.setRedirect(true);
        return p;
		
	}

}