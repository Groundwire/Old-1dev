@isTest
private class RestExplorerControllerTest {

    static testmethod void testInitialization() {
        Test.setCurrentPage(Page.RestExplorer);
        
        RestExplorerController c = new RestExplorerController();
        
        System.assertEquals('/services/data', c.url);
        System.assertEquals(null, c.response);
        System.assertEquals(null, c.rawResponse);
    }

    static testmethod void testAutoExecution() {
        Test.setCurrentPage(Page.RestExplorer);
        ApexPages.currentPage().getParameters().put('autoExec', '1');
        RestExplorerController c = new RestExplorerController();
        
        System.assertEquals('/services/data', c.url);
    }

    static testmethod void testCustomUrl() {
        Test.setCurrentPage(Page.RestExplorer);
        final String customUrl = '/services/data/blah';
        ApexPages.currentPage().getParameters().put('url', customUrl);
        RestExplorerController c = new RestExplorerController();
        
        System.assertEquals(customUrl, c.url);
    }

    static testmethod void testBadUrlThrowsException() {
        Test.setCurrentPage(Page.RestExplorer);
        RestExplorerController c = new RestExplorerController();
        final Integer previousMessages = ApexPages.getMessages().size();
        
        c.url = 'xxx';
        c.execute();
        System.assertEquals(previousMessages + 1, ApexPages.getMessages().size());
    }

    static testmethod void testGetAvailableRequestMethodsl() {
        Test.setCurrentPage(Page.RestExplorer);

        RestExplorerController c = new RestExplorerController();
        
        System.assert(null != c.getAvailableRequestMethods());
    }

    static testmethod void testGetIsBaseUrlConfigured_WhenNotConfigured() {        
        Test.setCurrentPage(Page.RestExplorer);
        final Integer previousMessages = ApexPages.getMessages().size();
        
        DELETE [SELECT Id FROM RestExplorerConfig__c];
        RestExplorerController c = new RestExplorerController();
        
        System.assert(!c.getIsBaseUrlConfigured());
        System.assertEquals(previousMessages + 1, ApexPages.getMessages().size());
    }

    static testmethod void testGetIsBaseUrlConfigured_WhenConfigured() {        
        Test.setCurrentPage(Page.RestExplorer);
        RestExplorerController c = new RestExplorerController();
        
        RestExplorerConfig__c config = new RestExplorerConfig__c(
                                            name     = 'baseUrl', 
                                            value__c = 'http://www.example.com');
        UPSERT config name;
        
        System.assert(c.getIsBaseUrlConfigured());
    }
}