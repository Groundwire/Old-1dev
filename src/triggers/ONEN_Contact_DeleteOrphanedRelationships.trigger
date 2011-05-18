trigger ONEN_Contact_DeleteOrphanedRelationships on Contact (after delete) {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	//intantiate our relationships class
	ONEN_ContactRelationships relationships = new ONEN_ContactRelationships();
	for (Contact contact : Trigger.old) {
		relationships.contactIdsForCleanup.add(contact.Id);
	}
	system.debug('count of deleted contacts: ' + relationships.contactIdsForCleanup.size());
	if (relationships.contactIdsForCleanup.size()>0) {
		relationships.deleteOrphanedContactRelationships();
	}
}