public virtual class ONEN_EmailTemplates {

/*-----------------------------------------------------------------------------------------------
* Written by Matthew Scholtz, copyright (c) 2009 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* this class was created for GPTF but might have wider application
* it expects you to pass in a list of template names when instantiating,
*  and will create a map to the template ID's
* we do it this way b/c the # of templates in an instance is unknown and potentially large
*  so this avoids any gov. limits issues
*
-----------------------------------------------------------------------------------------------*/

	protected  Map<String,Id> templateNameMap = new Map<String,Id>();
	public list<String> templateNamesToQuery = new list<String>();
	
	public ONEN_EmailTemplates (list<string> names) {
		templateNamesToQuery = names;
		getRecordTypesMap();
	}
	
	//method to put the record type info into two maps for access
	protected virtual void getRecordTypesMap() {
		//query all active record types order by object and then record type
		List<EmailTemplate> templates = [SELECT id, Name FROM EmailTemplate 
			where Name IN :templateNamesToQuery AND IsActive=true ORDER BY Name];
		for(EmailTemplate thisTemp: templates) {
			templateNameMap.put(thisTemp.Name,thisTemp.Id);
		}
		system.debug ('templateNameMap:' + templateNameMap);
	}

	public virtual Id GetTemplateId(String name) {
		return templateNameMap.get(name);
	}
	
    static testmethod void testTNM() {
    	ONEN_EmailTemplates et = new ONEN_EmailTemplates(new list<string>{'test'});
    	system.debug(et.GetTemplateId('test')); 
    }
}