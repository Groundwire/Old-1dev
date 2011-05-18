trigger ONEN_Account_DeleteOrphanedRelationships on Account (after delete) {
// Written by Matthew Scholtz, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/	

	//intantiate our relationships class
	ONEN_AccountRelationships relationships = new ONEN_AccountRelationships();
	for (Account account : Trigger.old) {
		relationships.accountIdsForCleanup.add(account.Id);
	}
	system.debug('count of deleted accounts: ' + relationships.accountIdsForCleanup.size());
	if (relationships.accountIdsForCleanup.size()>0) {
		relationships.deleteOrphanedaccountRelationships();
	}
}