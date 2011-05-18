global class GW_Describe {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* This class allows easy access to object and field description information from within other classes.
*
* It is called statically, and therefore will supply the same information to all calls made from
* within one transaction, or set of trigger calls. This is beneficial because this info should
* be the same for all calls in a transaction, and by calling it statically we reduce the calls
* that are made, making the total transaction more efficient
-----------------------------------------------------------------------------------------------*/
	
	// throw custom exceptions when a bogus object or field is provided. 
	public class SchemaDescribeException extends Exception {}
	
	//maps to hold the describe info
	private static Map<String, Schema.SObjectType> gd;
	private static Map<String, Schema.DescribeSObjectResult> objectDescribes = new Map<String, Schema.DescribeSObjectResult>();
	private static Map<String, Map<String, Schema.SObjectField>> fieldTokens = new Map<String,Map<String, Schema.SObjectField>>();
	private static Map<String, Map<String, Schema.DescribeFieldResult>> fieldDescribes = new Map<String,Map<String, Schema.DescribeFieldResult>>();
		
	/*******************************************
	* Gets describe maps for a new object
	********************************************/
	static void fillMapsForObject(string objectName) {
		// get the object map the first time
		if (gd==null) gd = Schema.getGlobalDescribe();
		
		// get the object description
		if (gd.containsKey(objectName)) {
			
			if (!objectDescribes.containsKey(objectName))
				objectDescribes.put(objectName, gd.get(objectName).getDescribe());
		} else {
			throw new SchemaDescribeException('Invalid object name \'' + objectName + '\'');
		}
	}

	/*******************************************
	* Gets a field map for a new object/field pair
	********************************************/
	static void fillFieldMapsForObject(string objectName, string fieldName) {
		// get the object map the first time
		fillMapsForObject(objectName);
		
		// get the field description
		if (!fieldTokens.containsKey(objectName)) {
			fieldTokens.put(objectName, objectDescribes.get(objectName).fields.getMap());
			fieldDescribes.put(objectName, new Map<String, Schema.DescribeFieldResult>());
		}
		if (!fieldDescribes.get(objectName).containsKey(fieldName)) {
			if (fieldTokens.get(objectName).containsKey(fieldName)) {
				Schema.DescribeFieldResult dfr = fieldTokens.get(objectName).get(fieldName).getDescribe(); 
				fieldDescribes.get(objectName).put(fieldName, dfr);
			} else {
				throw new SchemaDescribeException('Invalid field name \'' + fieldName + '\'');			
			}
		}
	}
	
	/*******************************************
	* Gets all field maps for a new object
	********************************************/
	static void fillFieldMapsForObject(string objectName) {
		// get the object map the first time
		fillMapsForObject(objectName);
		
		// get the field description
		if (!fieldTokens.containsKey(objectName)) {
			fieldTokens.put(objectName, objectDescribes.get(objectName).fields.getMap());
			fieldDescribes.put(objectName, new Map<String, Schema.DescribeFieldResult>());
		}
		
		//Map<String, Schema.SObjectField> fieldsMap = objectDescribes.get(objectName).fields.getMap();
		if (fieldTokens.get(objectName).size() != fieldDescribes.get(objectName).size()) {
			for ( string fieldName : fieldTokens.get(objectName).keyset()) {
				if (!fieldDescribes.get(objectName).containsKey(fieldName)) {
					Schema.DescribeFieldResult dfr = fieldTokens.get(objectName).get(fieldName).getDescribe(); 
					fieldDescribes.get(objectName).put(fieldName, dfr);
				}
			}
		}
	}

	/*******************************************
	* Returns new object of given type
	********************************************/
	global static SObject getPrototypeObject(String objectName) {
		// make sure we have this object's schema mapped
		if (!objectDescribes.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		return gd.get(objectName).newSObject();
	}	

	/*******************************************
	* Returns object friendly name
	********************************************/
	global static string getObjectLabel(String objectName) {
		// make sure we have this object's schema mapped
		if (!objectDescribes.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		return objectDescribes.get(objectName).getLabel();
	}	

	/*******************************************
	* Returns object describe data
	********************************************/
	global static Schema.DescribeSObjectResult getObjectDescribe(String objectName) {
		// make sure we have this object's schema mapped
		if (!objectDescribes.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		return objectDescribes.get(objectName);
	}	

	/*******************************************
	* Compares Id to verify object type
	********************************************/
	global static boolean isObjectIdThisType(Id salesforceId, String objectName) {
		// make sure we have this object's schema mapped
		if (!objectDescribes.containsKey(objectName)) 
			fillMapsForObject(objectName);
		
		// now grab the requested id prefix
		boolean ret = false;
		if (salesforceId != null) {
			string prefix = objectDescribes.get(objectName).getKeyPrefix();
			if (prefix != null) 
				ret = ((string)(salesforceId)).startsWith(prefix);
		}
		return ret;
	}	
	
	/*******************************************
	* Returns all field describe data
	********************************************/
	global static Map<String, Schema.DescribeFieldResult> getAllFieldsDescribe(String objectName) {

		// make sure we have this field's schema mapped
		fillFieldMapsForObject(objectName);
		
		Map<String, Schema.DescribeFieldResult> fieldMap = fieldDescribes.get(objectName);
		return fieldMap;
	}
		
	/*******************************************
	* Gives field type name - ID, STRING, TEXTAREA, DATE, DATETIME, BOOLEAN, REFERENCE, 
		PICKLIST, MULTIPICKLIST, CURRENCY, DOUBLE, INTEGER, PERCENT, PHONE, EMAIL
	********************************************/
	global static string getFieldType(String objectName, String fieldName) {
		// make sure we have this field's schema mapped
		if (!fieldDescribes.containsKey(objectName) || !fieldDescribes.get(objectName).containsKey(fieldName)) 
			fillFieldMapsForObject(objectName, fieldName);
		
		Schema.DescribeFieldResult dfr = fieldDescribes.get(objectName).get(fieldName);
		return dfr.getType().name();
	}	
		
	/*******************************************
	* Returns field describe data
	********************************************/
	global static Schema.DescribeFieldResult getFieldDescribe(String objectName, String fieldName) {
		// make sure we have this field's schema mapped
		fieldName = fieldName.toLowerCase();
		if (!fieldDescribes.containsKey(objectName) || !fieldDescribes.get(objectName).containsKey(fieldName)) 
			fillFieldMapsForObject(objectName, fieldName);
		
		Schema.DescribeFieldResult dfr = fieldDescribes.get(objectName).get(fieldName);
		return dfr;
	}

	/*******************************************
	* Gives field friendly name
	********************************************/
	global static string getFieldLabel(String objectName, String fieldName) {
		// make sure we have this field's schema mapped
		fieldName = fieldName.toLowerCase();
		if (!fieldDescribes.containsKey(objectName) || !fieldDescribes.get(objectName).containsKey(fieldName)) 
			fillFieldMapsForObject(objectName, fieldName);
		
		Schema.DescribeFieldResult dfr = fieldDescribes.get(objectName).get(fieldName);
		return dfr.getLabel();
	}		

	// TEST
	static testmethod void testDescribe() {
		
		string s;
		
		Schema.DescribeSObjectResult res = GW_Describe.getObjectDescribe('Contact');		
		system.assertEquals(res.getName(), 'Contact');
		s = GW_Describe.getObjectLabel('Contact');
		system.assertEquals (s, res.getLabel());

		account a = new account(name='Test');
		insert a;
		system.assert(isObjectIdThisType(a.id, 'Account'));
		
		s = GW_Describe.getFieldLabel('Account', 'LastModifiedDate');
		integer calls = limits.getfieldsdescribes();
		
		Schema.DescribeFieldResult fr = GW_Describe.getFieldDescribe('Account', 'CreatedDate');		
		s = GW_Describe.getFieldLabel('Account', 'CreatedDate');
		system.assertEquals (s, fr.getLabel());

		Map<String, Schema.DescribeFieldResult> afd = getAllFieldsDescribe('Account');
		system.assertEquals ('BillingCity', afd.get('billingcity').getName());
		afd = getAllFieldsDescribe('Account');

		SObject acctObj = getPrototypeObject('Account');
		// should be able to cast to account
		account acct = (account)(acctObj);

		// another call should not use another describe
		system.assertEquals(limits.getfieldsdescribes(), calls);
		
		s = GW_Describe.getFieldType('Account', 'CreatedDate');
		system.assertEquals('DATETIME', s);
		
		try {
			s = GW_Describe.getObjectLabel('sdlkfjsdlkfjsldkfjlsdkfj');
		} catch (exception e) {
			system.assertEquals('Invalid object name \'sdlkfjsdlkfjsldkfjlsdkfj\'', e.getMessage());
		} 
		try {
			s = GW_Describe.getFieldLabel('Opportunity', 'sdlkfjsdlkfjsldkfjlsdkfj');
		} catch (exception e) {
			system.assertEquals('Invalid field name \'sdlkfjsdlkfjsldkfjlsdkfj\'', e.getMessage());
		} 
	}		
}