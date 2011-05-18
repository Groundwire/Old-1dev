trigger ONEN_Contact_MarkBadEmail on vr__VR_Email_History_Contact__c (after update, after insert) {
// Written by Dave Manelski, copyright (c) 2008 ONE/Northwest
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

       // every time we a VR Email History is added to the contact record, or updated from Vertical Reponse
       // and the VR Email History Contact has a bounced checkbox marked as true, update the contact field
       // Bad Email Addresss to True.
      
       // declare an array of Contact Id's that will come from the list of VR Email History records that
       // have the Bounced checkbox checked (true)
       list<Id> ContactIdsToUpdate = new list<Id>();
      
       // declare a new variable to hold VR Email History records with bounced emails
       vr__VR_Email_History_Contact__c BouncedEmail = new vr__VR_Email_History_Contact__c();
      
       // declare an array of contact records to update that will be associated with our list of 
       // Contact Id's 
       list<Contact> ContactsToUpdate = new list<Contact>();
      
       // loop through a batch of VR Email History records, for those records that have Bounced checked,
       // pull the contact Id's and throw them into a list
       for (vr__VR_Email_History_Contact__c thisEmailRecord : trigger.new) {
   
        vr__VR_Email_History_Contact__c thisEmailOld = new vr__VR_Email_History_Contact__c();
        if ( trigger.isUpdate ) thisEmailOld = trigger.oldMap.get(thisEmailRecord.Id);
   
              if ( (trigger.isInsert && thisEmailRecord.vr__Bounced__c) || 
               (trigger.isUpdate && thisEmailRecord.vr__Bounced__c && thisEmailOld.vr__Bounced__c != true) ) {
                     ContactIdsToUpdate.add (thisEmailRecord.vr__Contact__c);
              }
       }
      
       // With our list of contact Id's, pull those contact records, set the Bad Email Address field to true,
       // and throw those contacts to update into a list
       if ( ContactIdsToUpdate.size() > 0 ) {
              for (Id BouncedContacts : ContactIdsToUpdate) {
                     Contact thisContact = new Contact (
                     Id = BouncedContacts, 
                     Bad_Email_Address__c = true
                     );
                     ContactsToUpdate.add (thisContact);
             
              }
             
              update ContactsToUpdate;
       } 

}