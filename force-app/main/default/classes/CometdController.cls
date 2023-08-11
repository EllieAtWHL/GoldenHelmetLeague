public without sharing class CometdController {
    @AuraEnabled(cacheable=true)
    public static String getSessionId() {

        String sessionId;
        if(UserInfo.getSessionId() == null){
            sessionId = ManageGuestUser.getSessionId();
        } else{
            sessionId = UserInfo.getSessionId();
        }
        return sessionId;
    }

    @AuraEnabled(cacheable=true)
    public static string getStoredSessionId(){
        return Self__c.getOrgDefaults().Session_Id__c;
    }

    @AuraEnabled
    public static void setStoredSessionId(){
        try {
            Self__c currentSettings = Self__c.getOrgDefaults();
            Self__c updatedSettings = new Self__c();
            updatedSettings.Id = currentSettings.Id;
            updatedSettings.Session_Id__c = getSessionId();
            upsert updatedSettings;
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}