public class RestExplorerController {  
    private final String BASE_REST_URL_PREFIX = '/services/data';
    
    public String url {get; set;}
    public String requestBody {get; set;}
    public String requestMethod {get; set;}
    public String rawResponseHeaders {get; private set;}
    public String rawResponse {get; private set;}
    public String response {get; private set;}
    
    private RestClient client;
    private RestResponseInstrumenter insturmenter;
    
    public RestExplorerController() {
        final RestExplorerConfig__c baseUrlConfig = RestExplorerConfig__c.getInstance('baseUrl');
        final String staticBaseUrl;
        if (baseUrlConfig != null) {
            staticBaseUrl = RestExplorerConfig__c.getInstance('baseUrl').value__c;
        } else {
            staticBaseUrl = 'http://naX.salesforce.com';
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 
                'Your REST Base URL has not been configured. Go to Setup | Develop | Custom Settings | Rest Explorer Configuration | Manage | New. ' + 
                'Set the name to \'baseUrl\' and the value to your Salesforce instance, for example \'https://na1.salesforce.com\'.'));
        }

        final String sessionId = UserInfo.getSessionId();
        ConnectorConfig config = new ConnectorConfig(staticBaseUrl, sessionId);
        client = new RestClient(config);
        
        requestMethod = RequestMethods.GET.name();
        
        insturmenter = new RestResponseInstrumenter(ApexPages.currentPage().getUrl());
        
        url = ApexPages.currentPage().getParameters().get('url');
        if(url == null) {
            url = BASE_REST_URL_PREFIX;
        }
        
        if (ApexPages.currentPage().getParameters().get('autoExec') == '1') {
            execute();
        }
    }

    public boolean getIsBaseUrlConfigured() {
        return null != RestExplorerConfig__c.getInstance('baseUrl');
    }

    public List<SelectOption> getAvailableRequestMethods() {
        List<SelectOption> options = new List<SelectOption>(); 
        
        for (RequestMethods rm : RequestMethods.values()) {
            options.add(new SelectOption(rm.name(), rm.name()));     
        }
         
        return options; 
    }


    public void execute() {
        try {
            // clear any old values, in case we don't populate them on this request
            rawResponseHeaders = null;
            rawResponse = null;
            response = null;
            ApexPages.currentPage().getParameters().put('autoExec',null);
            
            // clean up the URL
            url = url.trim().replaceAll(' ', '+');
            
            // validate URL
            if (url.indexOf(BASE_REST_URL_PREFIX) != 0) {
                throw new RestException('Invalid REST API Service URI. Must begin with \'' + BASE_REST_URL_PREFIX + '\'.');
            }
            
            // send the resonse    
            HttpResponse httpResponse = client.send(requestMethod,
                                        url, 
                                        RequestMethods.POST.name().equals(requestMethod) 
                                            ? requestBody 
                                            : null
                                       );
            
            // process the headers
            rawResponseHeaders = '';                 
            for (String headerKey : httpResponse.getHeaderKeys()) {
                if (headerKey == null) continue;
                rawResponseHeaders += headerKey + ': ' + httpResponse.getHeader(headerKey) + '\n';
            }
            
            // process the body
            rawResponse = httpResponse.getBody();
            response = insturmenter.instrument(rawResponse);
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
    }
}