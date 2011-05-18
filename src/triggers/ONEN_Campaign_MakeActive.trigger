trigger ONEN_Campaign_MakeActive on Campaign (before insert) {
// Written by Michael Paulsmeyer, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	//system.debug('checkPrimaryContact FIRED');
	for (Campaign c : Trigger.New) {
		//Set Campaign active checkbox to true
	//	system.debug('checkPrimaryContact EXECUTED');
		c.IsActive = true; 
	}
}