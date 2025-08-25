public with sharing class LeagueSetup {
    
    @AuraEnabled(cacheable=true)
    public static MFL__c getSettings(){
        Logger.setScenario('Retrieving MFL Settings');
        try {
            return MFL__c.getOrgDefaults();
        } catch (Exception e) {
            Logger.exception('Error retrieving MFL settings', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveSettings(MFL__c settings){
        Logger.setScenario('Saving MFL Settings');
        try {
            upsert settings;
        } catch (Exception e) {
            Logger.exception('Error saving MFL settings', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Draft_Settings__c getDraftSettings(){
        Logger.setScenario('Retrieving Draft Settings');
        try {
            return Draft_Settings__c.getOrgDefaults();
        } catch (Exception e) {
            Logger.exception('Error retrieving draft settings', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled
    public static void saveDraftSettings(Draft_Settings__c settings){
        Logger.setScenario('Saving Draft Settings');
        try {
            upsert settings;
        } catch (Exception e) {
            Logger.exception('Error saving draft settings', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void resetDraft(){
        Logger.setScenario('Resetting Draft');
        try {
            List<Pick__c> allPicks = [SELECT Id FROM Pick__c];
            delete allPicks;
            Logger.info('Deleted ' + allPicks.size() + ' picks');
            Logger.saveLog();

            DraftUpdated__e event = new DraftUpdated__e();
            EventBus.publish(event);
            
        } catch (Exception e) {
            Logger.exception('Error resetting draft', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }

}