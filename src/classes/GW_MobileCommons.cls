public with sharing class GW_MobileCommons {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* 
* interface to free Mobile Commons web service
* give it a latitude and longitude, get back district information
* 
* SAMPLE USAGE:
	GW_MobileCommons mc = new GW_MobileCommons();
	mc.latitude = 48;
	mc.longitude = -122;

	// callout to get the districts		
	mc.getDistricts();

	if (mc.error != null) {		
		// report the result
		system.debug('State Abbreviation: ' + mc.state);
		system.debug('Federal Congressional: ' + mc.congress);
		system.debug('State Senate: ' + mc.stateSenate);
		system.debug('State House: ' + mc.stateHouse);
	} else {
		system.debug('ERROR: ' + mc.error);
	}
*
-----------------------------------------------------------------------------------------------*/

	// endpoints
	final string endpoint = 'congress.mcommons.com/districts/lookup.xml';
	final string testXML = '<response><lat>48</lat><lng>-122</lng><federal><state>WA</state><district>2</district><display_name>WA 2nd</display_name></federal><state_lower><state>WA</state><district>039</district><display_name>WA 39th</display_name></state_lower><state_upper><state>WA</state><district>039</district><display_name>WA 39th</display_name></state_upper></response>';
	public static boolean isTest = false;

	// properties
	public decimal latitude { get; set; }
	public decimal longitude { get; set; }
	
	public string response { get; private set; }
	public string error { get; private set; }
	public string state { get; private set; }
	public integer congress { get; private set; }
	public integer stateSenate { get; private set; }
	public integer stateHouse { get; private set; }
	
	// call the service and return the callout status code
	public void getDistricts() {
		
		// initialize 
		response = error = state = null;
		congress = stateSenate = stateHouse = null;
		
		if (latitude != null && longitude != null) {

			Http h = new Http();
            HttpRequest req = new HttpRequest();
	        req.setMethod('GET');
            req.setEndpoint('http://' + endpoint + 
            	'?lat=' + string.valueOf(latitude) +
            	'&lng=' + string.valueOf(longitude));
            req.setTimeout(3000);	// three seconds should be plenty    	            
            
            try {
            	httpResponse resp;
				Dom.Document doc;
	            integer status;
				if (isTest) {
					doc = new Dom.Document();
					doc.load(testXml);
					response = testXml;
					status = 200;					
				} else {					
		            resp = h.send(req);
					response = resp.getBody();
					status = resp.getStatusCode();
				}								
				if (status == 200) {
					if (response != null) {
						// Parse the xml and retrieve the root element
						if (!isTest)
							doc = resp.getBodyDocument();
						Dom.XMLNode root = doc.getRootElement();
						
						// check for error
						Dom.XMLNode errNode = root.getChildElement('error', null);
						if (errNode != null) {
							error = errNode.getText();
						} else {
						system.debug(logginglevel.warn, root.getchildelements());
							// get the details
							state = root.getChildElement('federal', null).getChildElement('state', null).getText(); 
							congress = integer.valueOf(
								root.getChildElement('federal', null).getChildElement('district', null).getText()
							);
							stateSenate = integer.valueOf(
								root.getChildElement('state_upper', null).getChildElement('district', null).getText()
							);
							stateHouse = integer.valueOf(
								root.getChildElement('state_lower', null).getChildElement('district', null).getText()
							);
						} 
					} else {
						error = 'No response from Mobile Commons service.';
						system.debug(loggingLevel.WARN, error);						
					}
				} else {
					error = 'Unexpected response from Mobile Commons service: \n' + response;
					system.debug(loggingLevel.WARN, error);
				}
            } catch( System.Exception e ) {
            	if (e.getMessage().startsWith('Unauthorized endpoint')) {
					error = 'Before using the Mobile Commons service, an administrator must go to Setup => Security => Remote Site Settings ' +
						'and add the following endpoint:  http://' + endpoint;
            	} else {
					error = 'Error communicating with Mobile Commons service: \n' + e.getMessage();
            	}
				system.debug(loggingLevel.WARN, error);
			}
    		
		}
	}

	// TESTS

	public static testMethod void testMC() {
		GW_MobileCommons.istest = true;
		GW_MobileCommons mc = new GW_MobileCommons();
		mc.latitude = 48;
		mc.longitude = -122;
		mc.getDistricts();
		system.assertEquals(2, mc.congress);
	}
}