trigger ONEN_Account_ProctectIndividualAccount on Account (before delete, before insert, before update) {
// Written by Matthew Scholtz, copyright (c) 2009 Groundwire
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	string indName = ONEN_DefaultAccount.individualAcctName;

	if (trigger.isDelete) {
		for ( Account thisAccount : trigger.old ) {
			if ( thisAccount.Id == ONEN_DefaultAccount.getIndividualAccountId() ) {
				thisAccount.addError ('You cannot delete the ' + indName + ' organization.');
			}
		}
	}
	
	// for updates, check renames
	if (trigger.isUpdate) {
		Account[] AcctsRenamedTo = new Account[0];
		Account[] AcctsRenamedFrom = new Account[0];
		
		for (Account Acct : trigger.new) {
			Account oldAcct = trigger.oldmap.get(Acct.Id);
			
			// check which are renamed to or from the ind acct
			if (Acct.Name==indName && Acct.Name!=oldAcct.Name) {
				AcctsRenamedTo.add(Acct);
			}
			if (oldAcct.Name==indName && Acct.Name!=oldAcct.Name) {
				AcctsRenamedFrom.add(Acct);
			}
		}
		
		integer count;
		if (AcctsRenamedTo.size()>0 || AcctsRenamedFrom.size()>0) {
			count = ONEN_AccountMaintenance.getIndAcctCount(indName);
			system.debug ('protectindacct vars  count:' + count + ' acctsrenamedfrom:' + AcctsRenamedFrom.size() + '  acctsrenamedto:' + AcctsRenamedTo.size() );
			
			// if there's already one or more named Ind, reject any renamed to that
			if (AcctsRenamedTo.size()>0 && count>0) {
				for (Account Acct : AcctsRenamedTo) {
					Acct.addError ('There is already an Organization named ' + indName + '.  You cannot have 2 Organizations with that name.');
				}
			}		
			
			// reject renaming Ind acct unless it won't leave us with exactly one
			if ( (count + AcctsRenamedTo.size() - AcctsRenamedFrom.size() ) <> 1) {
				for (Account Acct : AcctsRenamedFrom) {
					Acct.addError ('You cannot change the name of the this Organization because it is required for proper function of the database.');
				}
			}
		}		
	}
	
	// for insert, just make sure there isn't a duplicate (either with existing recs or within set)
	if (trigger.isInsert) {
		Account[] newIndAccts = new Account[0];
		for (Account acct : trigger.new) {
			if (acct.Name==indName) {
				newIndAccts.add (acct);
			}
		}
		if (newIndAccts.size()>0) {
			integer count = ONEN_AccountMaintenance.getIndAcctCount(indName);
			if (count>0 || newIndAccts.size()>1) {
				for (Account acct : newIndAccts) {
					acct.addError('You cannot add a duplicate ' + indName + ' organization.');
				}
			}
		}
	}

}