public virtual class RestClient {
        
    private ConnectorConfig config;
    
    public RestClient(ConnectorConfig config) {
        this.config = config;
    }
    
    public HttpResponse send(String method, String url, String body) {
        HttpRequest req = new HttpRequest(); 
        req.setEndpoint(config.getBaseUrl() + url);
        req.setHeader('Authorization', 'OAuth ' + config.getSessionId()); 
        req.setHeader('X-PrettyPrint', 'true'); 
        
        if (method.equals(RequestMethods.POST.name())) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
        } else if (body != null) {
            throw new RestException('Request body should be null for ' + method);
        }
        
        req.setMethod(method);
        return send(req); 
    }
    
    virtual HttpResponse send(HttpRequest req) {
        return new Http().send(req);
    }   
}