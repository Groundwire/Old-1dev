@isTest 
private class ONEN_TEST_ProtectIndividualAccount {
// Written by Matthew Scholtz, copyright (c) 2010 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	static testmethod void TestIndividualAccountDelete () {
		
		Account IndAcct = [SELECT id, Name FROM Account WHERE id =: ONEN_DefaultAccount.getIndividualAccountId() LIMIT 1];

		// first test account can't be deleted		
		string error;
		try {
			delete IndAcct;	
		} catch ( DmlException e ) {
			error = e.getMessage();
			system.debug (error);
		}
		System.Assert ( error.contains('Individual') );

		// next test can't create a duplicate via insertion
		Account dupAcct = new Account (	Name = indAcct.name );
		try {
			insert dupAcct;
		} catch  ( DmlException e ) {
			error = e.getMessage();
		}		
		System.Assert ( error.contains('duplicate') );
		
		// finally test can't create dup via rename of other acct
		dupAcct.Name = 'Some Other Name';
		insert dupAcct;
		dupAcct.Name = indAcct.name;
		try {
			update dupAcct;
		} catch  ( DmlException e ) {
			error = e.getMessage();
		}		
		System.Assert ( error.contains('Organization') );

		// next test can't rename it to something else		
		IndAcct.Name = 'Renamed Name';
		try {
			update IndAcct;
		} catch  ( DmlException e ) {
			error = e.getMessage();
		}
		System.Assert ( error.contains('Organization') );		
	}
}