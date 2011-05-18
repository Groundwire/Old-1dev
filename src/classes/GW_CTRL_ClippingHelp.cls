public class GW_CTRL_ClippingHelp {
// Written by Dave Manelski, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
	
	public string serverName;
	public pageReference bookmarkletLink { get; private set; }
	public string URLFieldId;
	public string contentFieldId;
	
	public GW_CTRL_ClippingHelp() { 
		
	}
	 /*
	function generateLink() { 
	var clippingObjectCode = getObjectCode(); 
	var servName = getServerName(); 
	var URLFieldId = getURLFieldId(); 
	var contentFieldId = getClippingContentFieldId(); 
	
	var linkDestination = "javascript:location.href='https://" + servName + ".salesforce.com/" + clippingObjectCode + "/e?retURL=%2F" + clippingObjectCode + "%2Fo&" + URLFieldId + "='+encodeURIComponent(location.href)+'&" + getClippingContentFieldId() + "='+encodeURIComponent((window.getSelection%20?%20window.getSelection()%20:%20document.getSelection%20?%20document.getSelection()%20:%20document.selection.createRange().text))+'&Name='+encodeURIComponent(document.title)"; 
	var linkHTML = "<a id=\"link\" href=\"" + linkDestination + "\">Clipping Bookmarklet</a>"; 
	document.getElementById('link_div').innerHTML = linkHTML;	
	document.getElementById('bookmarklet_instuctions_div').style.visibility = "visible";	
	} 
	
	function getServerName() { 
	return document.getElementById('serverName').value; 
	} 
	
	function getObjectCode() { 
	return document.getElementById('objectCode').value; 
	} 
	
	function getURLFieldId() { 
	return document.getElementById('clippingURLFieldId').value; 
	} 
	
	function getClippingContentFieldId() { 
	return document.getElementById('clippingContentFieldId').value; 
	} 
	*/

}