trigger ONEN_Lead_AddCompany on Lead (before insert, before update) {
// Written by Steve Andersen, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

	//this syntax handles the bulk nature of the trigger. Trigger.New is a list of Contacts
	//only process the Contacts if we have an Account Id to put on the record

	for (Lead l : Trigger.New) {
		if (l.Company == NULL||l.Company == '') {			
				l.Company ='[not provided]';
		}
	}
}