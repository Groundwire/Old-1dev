// Written by Steve Andersen, copyright (c) 2007 ONE/Northwest
// This program is released under the GNU General Public License. http://www.gnu.org/licenses/
@isTest 
private class ONEN_TEST_ContactSetDefaultAccount {
 
    static testMethod void TestAccountAdd() {   
        
        //fake the individual Account for tests
        //this needs to be included in all tests that create contacts or convert leads
        //if not included, the tests will touch live data and may interrupt functioning of
        //the production database
        String individualAccountNameForTests = 'IndividualAccountForTests';
        ONEN_DefaultAccount.setIndividualAccountForTests(individualAccountNameForTests);
         
        Id FirstContactId;
        //create first contact
        //UnitTestData.CreateTestContact(1);
        Contact firstContact = new Contact (
            FirstName='Joe',
            LastName='Johanssen_for_tests'          
        );
        //create the contact
        insert firstContact;
        //the AccountAdd.tgr should fire on this insert, putting the default Account Id on the Contact
        
        //get the Account Name from the newly creatd Contact
        Contact createdFirstContact = [select Account.Name from Contact where Id =:firstContact.id];
        //the default Account should have been added to the contact
        System.assertEquals(individualAccountNameForTests,createdFirstContact.Account.Name);
    }
}