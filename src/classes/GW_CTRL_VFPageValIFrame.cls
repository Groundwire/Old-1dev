public with sharing class GW_CTRL_VFPageValIFrame {
// Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	public string retURL {get; set; }

	public GW_CTRL_VFPageValIFrame(ApexPages.StandardController controller){
	}
	
	public PageReference Save() {
		// go to the success page
		if (retURL != null) {
			PageReference p = new PageReference(retURL);
      		return p;
  		} else {
   			return null;
		}
	}
}