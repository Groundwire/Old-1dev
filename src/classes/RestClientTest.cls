@isTest
private class RestClientTest {
    
    private class RestClientSpy extends RestClient {

        private Integer sendCount = 0;
        private HttpRequest httpRequest;
        
        RestClientSpy() {
            super(new ConnectorConfig('https://www.example.com', UserInfo.getSessionId()));
        }
        
        public HttpResponse send(HttpRequest httpRequest) {
            System.assert(null != httpRequest);
        
            this.sendCount++;
            this.httpRequest = httpRequest;
            return new HttpResponse();
        }
        
        Integer getSendCount() {
            return sendCount;
        }
        
        HttpRequest getHttpRequest() {
            return httpRequest;
        }
    }

    static testmethod void testGet() { 
        RestClientSpy spy = new RestClientSpy();
        
        spy.send(RequestMethods.GET.name(), '/services/data', null);
        
        System.assertEquals(1, spy.getSendCount());
        System.assertEquals(null, spy.getHttpRequest().getBody()); 
        System.assertEquals('GET', spy.getHttpRequest().getMethod()); 
    }

    static testmethod void testGetWithBodyThrowsRestException() { 
        RestClientSpy spy = new RestClientSpy();
        
        try {
            spy.send(RequestMethods.GET.name(), '/services/data', 'A BODY');
            System.assert(false);
        } catch (RestException e) {
            // expected
        }
    }
            
    static testmethod void testPost() { 
        RestClientSpy spy = new RestClientSpy();
        
        final String expectedBody = 'xxx';
        spy.send(RequestMethods.POST.name(), '/services/data', expectedBody);
        
        System.assertEquals(1, spy.getSendCount());
        System.assertEquals(expectedBody, spy.getHttpRequest().getBody()); 
        System.assertEquals('POST', spy.getHttpRequest().getMethod()); 
    }
}