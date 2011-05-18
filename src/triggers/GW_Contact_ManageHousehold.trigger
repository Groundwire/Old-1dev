trigger GW_Contact_ManageHousehold on Contact (after delete, after insert, after undelete, 
after update, before insert, before update) {
// Written by Evan Callahan, copyright (c) 2007 NPower Seattle
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
    
    GW_Householding gwhh = new GW_Householding();
    
    if (trigger.isBefore) {

        // don't run this recursively when fixing addresses 
        if (!GW_Householding.nowCopyingAddresses) {
        
            // don't run this recursively when creating 'second' contacts 
            if (!trigger.isInsert || Trigger.new[0].SecondContactLastName__c != 'Second Contact') { 
        
                // compile a list of households that need updating
                onen_household__c[] newHouseholds = new onen_household__c[]{};
        
                // also save contacts that have no address
                id[] needAddress = new id[]{};
        
                // loop through the records
                for (Contact c : Trigger.New) {
                    // add this contact to the update list if no home address
                    if (c.otherstreet == null && c.onen_household__c != null) {
                        needAddress.add(c.onen_household__c);
                    }

                    // check if this contact is newly deceased
                    if ( c.Deceased__c == true && trigger.oldmap != null && 
                        trigger.oldmap.containsKey(c.id) && !trigger.oldmap.get(c.id).deceased__c )
                            c.ONEN_Household__c = null;
        
                    // create a blank household for each contact that doesn't have one
                    if (c.onen_household__c==null) {
                        newHouseholds.add(new onen_household__c(Name='New Household'));
                        // NOTE: household names get corrected in the "after" trigger
                    }
                }
                if (newHouseholds.size() > 0) insert newHouseholds;
                
                // get missing addresses
                Map<id, contact> addresses = new Map<id, contact>{};
                if (needAddress.size() > 0) {
                    for (contact c : [select id, onen_household__c, otherStreet, otherCity, otherState, otherPostalCode, otherCountry from contact where onen_household__c in :needAddress and otherStreet!=null]) {
                        addresses.put(c.onen_household__c, c);
                    }
                }
        
                // loop through the new records again
                integer i = 0;
                for (Contact c : Trigger.new) {
                    // set the household to one of the 'New' ones
                    if (c.onen_household__c==null) {
                        c.onen_household__c = newHouseholds[i].id;
                        i++;
                    }
                    // fill in preferred address, if blank
                    if (c.primary_address__c == null) 
                        c.primary_address__c = (c.mailingStreet != null) ? 'Work' : (c.OtherStreet != null) ? 'Home' : null;        
                    // set the address from other household member, if this is a new person without one
                    if (c.otherStreet == null && trigger.isInsert) {
                        if (addresses.containsKey(c.onen_household__c)) {
                            contact addr = addresses.get(c.onen_household__c);
                            c.otherStreet = addr.otherStreet;
                            c.otherCity = addr.otherCity;
                            c.otherState = addr.otherState;
                            c.otherPostalCode = addr.otherPostalCode;
                            c.otherCountry = addr.otherCountry;
                        }
                    }
        
                    // create a 'second' contact in the same household
                    if (c.SecondContactFirstName__c != null) {
        
                        // use same last name if last is blank
                        if (c.SecondContactLastName__c==null) c.SecondContactLastName__c = c.LastName;
                        
                        GW_Householding.secondContacts.add(new Contact(
                            Salutation = c.SecondContactSalutation__c,
                            FirstName = c.SecondContactFirstName__c,
                            LastName = c.SecondContactLastName__c,
                            Email = c.SecondContactEmail__c,
                            onen_household__c = c.onen_household__c,
                            AccountId = ONEN_DefaultAccount.GetIndividualAccountId(),
                            SecondContactLastName__c='Second Contact')
                        );
                        c.SecondContactFirstName__c = null;
                    }
                    c.SecondContactLastName__c = null;
                    c.SecondContactEmail__c = null;
                }
            }
        }

    } else {
        
        // AFTER TRIGGER
        /* need to special case if this is a second contact created by apex after saving a regular 
           contact record. it is a tricky event path -- we come to this trigger after saving a 
           primary contact, and again recursively when doing the second insert here
           I did all this just so that I could add the second contact *after* the first */
        if (!trigger.isInsert || trigger.new[0].SecondContactLastName__c!='Second Contact') {
               
            if (!GW_Householding.secondContacts.isEmpty()) {
                // insert the secondary contacts, if any
                insert GW_Householding.secondContacts;
                GW_Householding.secondContacts.clear();
            }  
            if (!GW_Householding.nowCopyingAddresses) {
                Set<Id> HHChanges = new Set<Id>();
                Map<Id, Contact> AddressChanges = new Map<Id, Contact>{};
        
                for (Contact ContactAfter : Trigger.isDelete ? Trigger.old : Trigger.new) {
    
                    // track whether to update the address
                    Boolean addressChange = false;
                    Boolean hhChange = false;
                    
                    if (!Trigger.isUpdate) {
                        // add this id (and the old one) to the list of changed households
                        HHChanges.add(ContactAfter.onen_household__c);
                        addressChange = !Trigger.isDelete;
                    } else {
                        // for update trigger, check for changes to the data
                        Contact ContactBefore = trigger.oldmap.get(ContactAfter.id);
                        hhChange = ContactBefore.onen_household__c!=ContactAfter.onen_household__c || ContactBefore.Not_in_HH_Name__c!=ContactAfter.Not_in_HH_Name__c;        
                        Boolean nameChange = ContactBefore.FirstName!=ContactAfter.FirstName||ContactBefore.LastName!=ContactAfter.LastName||ContactBefore.Salutation!=ContactAfter.Salutation;
                        addressChange = ContactBefore.OtherStreet!=ContactAfter.OtherStreet||ContactBefore.OtherCity!=ContactAfter.OtherCity||ContactBefore.OtherState!=ContactAfter.OtherState||ContactBefore.OtherPostalCode!=ContactAfter.OtherPostalCode||ContactBefore.OtherCountry!=ContactAfter.OtherCountry;
    
                        if (hhChange || nameChange) {
                            HHChanges.add(ContactBefore.onen_household__c);
                            HHChanges.add(ContactAfter.onen_household__c);
                        }
                    }
                    // mark addresses that need propagating
                    if (hhChange || addressChange) {
                        AddressChanges.put(ContactAfter.onen_household__c, ContactAfter);
                    }
                }
                
                // call the update code for householding
                if (!HHChanges.isEmpty()) gwhh.UpdateNames(HHChanges);
                if (!AddressChanges.isEmpty()) gwhh.UpdateAddresses(AddressChanges);
            }
        }       
    }
}