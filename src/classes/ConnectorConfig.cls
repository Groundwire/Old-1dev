public with sharing class ConnectorConfig {
    private String baseUrl;
    private String sessionId;
    
    public ConnectorConfig(String baseUrl, String sessionId) {
        this.baseUrl = baseUrl;
        this.sessionId = sessionId;
    }
    
    public String getBaseUrl() {
        return baseUrl;
    }

    public String getSessionId() {
        return sessionId;
    }
}