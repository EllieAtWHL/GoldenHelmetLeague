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
            upsert settings;
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
            upsert settings;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void resetDraft(){
        try {
            List<Pick__c> allPicks = [SELECT Id FROM Pick__c];
            delete allPicks;

            DraftUpdated__e event = new DraftUpdated__e();
            EventBus.publish(event);
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

}