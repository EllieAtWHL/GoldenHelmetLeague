public with sharing class LeagueSetup {
    
    @AuraEnabled(cacheable=true)
    public static MFL__c getSettings(){
        try {
            return MFL__c.getOrgDefaults();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveSettings(MFL__c settings){
        try {
            MFL__c mflSettings = settings;
            update settings;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}