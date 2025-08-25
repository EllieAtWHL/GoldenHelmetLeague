public without sharing class CometdController {
    @AuraEnabled(cacheable=true)
    public static String getSessionId() {
        Logger.setScenario('Retrieving sessionId from initial method');

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
        Logger.setScenario('Retrieving sessionId from custom settings');
        try{
            return Self__c.getOrgDefaults().Session_Id__c;
        } catch (Exception e) {
            Logger.exception('Error retrieving stored sessionId', e);
            Logger.saveLog();
            throw new AuraHandledException('Error retrieving stored sessionId: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void setStoredSessionId(){
        Logger.setScenario('Storing sessionId');
        try {
            Self__c currentSettings = Self__c.getOrgDefaults();
            Self__c updatedSettings = new Self__c();
            updatedSettings.Id = currentSettings.Id;
            updatedSettings.Session_Id__c = getSessionId();
            upsert updatedSettings;
            
        } catch (Exception e) {
            Logger.exception('Error setting stored sessionId', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }
}