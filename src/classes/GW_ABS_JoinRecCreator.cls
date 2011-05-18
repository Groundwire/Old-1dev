public abstract class GW_ABS_JoinRecCreator {

	// if we have two objects related many-to-many (join object between them)
	// and if we start from a parent rec one side (the "source" object) and create a parent rec on the other side (the "inserted" object)
	// this code will automatically create a join object to link them
	// if we put the id of the source object rec in a field on the inserted object rec
	// this will generally be done via a VF redirect 

	public string sourceObjName;
	public string insertedObjName;
	public string joinObjName;
	
	public string sourceRecIDField;   	// field name in inserted obj holding ID of source rec
	public string sourceFK;				// field name in join obj for FK pointing to source obj
	public string insertedFK;			// ditto for inserted obj

	public sobject[] insertedRecs;

	public GW_ABS_JoinRecCreator(sobject[] insertedRecs) {
		// constructor
		this.insertedRecs = insertedRecs;
		setClassProperties();
	}
	
	public abstract void setClassProperties();	// subclass must implement this to set the properties at the top 
	/* example:
	public override void setClassProperties() {
		this.sourceObjName = 'Program__c';
		this.insertedObjName = 'Meal__c';
		this.joinObjName = 'Program_Meal__c';
		this.sourceRecIDField = 'temp_ProgramID__c'; 
		this.sourceFK = 'Program__c';	
		this.insertedFK = 'Meal__c';
	}
	*/	
	
	public virtual boolean createJoinRecs() {
		// given all the parameters, get the source obj id from the inserted rec, and use it to create a join obj
		boolean success = false;

		// create a reference to the right object
		SObject[] jrecs; 
		SObjectType token = Schema.getGlobalDescribe().get(this.joinObjName);
		// note must do this for now via a query (next 3 lines) due to SF bug - 
		//   see http://forums.sforce.com/t5/Apex-Code-Development/Bug-Dynamic-DML-not-allowed-on-SObject-lists/m-p/179624
		string soql = 'SELECT Id FROM ' + this.joinObjName + ' WHERE Id = \'000000000000000\' LIMIT 1';
		jrecs = Database.query(soql);
		jrecs.clear();
		
		for (SObject irec : insertedRecs) {
			// get the id's
			Id irecId = irec.Id;
			Id srecId = (Id) irec.get(this.sourceRecIdField);
			if (irecId != null && srecId != null) {
				SObject jRec = token.newSObject();
				// write the foreign keys
				jRec.put (this.sourceFK,srecId);
				jRec.put (this.insertedFK,irecId);
				jrecs.add (jRec);
			}
		}
		
		if (jrecs.size() > 0 ) {
			insert jrecs;
		}		
		return success;
	}
	
}