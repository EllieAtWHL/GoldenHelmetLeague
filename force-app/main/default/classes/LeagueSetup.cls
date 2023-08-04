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
            update settings;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Draft_Settings__c getDraftSettings(){
        try {
            return Draft_Settings__c.getOrgDefaults();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static void saveDraftSettings(Draft_Settings__c settings){
        try {
            update settings;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}