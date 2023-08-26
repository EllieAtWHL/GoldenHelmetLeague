@isTest
public class LeagueSetupTest {

    @isTest
    static void getSettings_WithExistingRecord() {
        MFL__c newMFLRecord = new MFL__c();
        insert newMFLRecord;

        Test.startTest();
            MFL__c result = LeagueSetup.getSettings();
        Test.stopTest();

        Assert.areEqual(newMFLRecord.Id, result.Id);
    }

    @isTest
    static void saveSettings_Insert() {
        MFL__c newSettings = new MFL__c();
        newSettings.API_Key__c = 'Test Settings';

        Test.startTest();
            LeagueSetup.saveSettings(newSettings);
        Test.stopTest();

        MFL__c insertedSettings = MFL__c.getOrgDefaults();
        
        Assert.areEqual('Test Settings', insertedSettings.API_Key__c);
    }

    @isTest
    static void saveSettings_Update() {
        MFL__c updatedSettings = new MFL__c();
        updatedSettings.API_Key__c = 'Updated Settings';
        insert updatedSettings;

        updatedSettings.API_Key__c = 'New Updated Settings';

        Test.startTest();
            LeagueSetup.saveSettings(updatedSettings);
        Test.stopTest();

        MFL__c updatedRecord = MFL__c.getOrgDefaults();
        
        Assert.areEqual(updatedSettings.Id, updatedRecord.Id, 'Did not update org defaults');
        Assert.areEqual('New Updated Settings', updatedRecord.API_Key__c);
    }

    
    @isTest
    static void saveSettings_Exception() {
        MFL__c updatedSettings = new MFL__c();
        updatedSettings.Name = 'This name is going to be too long to allow it to be saved properly. I need to keep typing to make sure this is an enormous amount of characters and therefore will definitely fail to insert properly. I cant think of any other way of ensuring that I hit the exception route to test it properly.';

        Boolean exceptionThrown = false;
        Test.startTest();
            try {
                LeagueSetup.saveSettings(updatedSettings);
            } catch(Exception e){
                exceptionThrown = true;
            }
        Test.stopTest();

        Assert.areEqual(true, exceptionThrown, 'An exception was not thrown as expected');
    }

    @isTest
    static void getDraftSettings_WithExistingRecord() {
        Draft_Settings__c existingDraftSettings = new Draft_Settings__c();
        insert existingDraftSettings;

        Test.startTest();
            Draft_Settings__c result = LeagueSetup.getDraftSettings();
        Test.stopTest();

        Assert.areEqual(existingDraftSettings.Id, result.Id);
    }

    @isTest
    static void saveDraftSettings_Insert() {
        Draft_Settings__c newDraftSettings = new Draft_Settings__c();
        newDraftSettings.Number_of_Rounds__c = 10;

        Test.startTest();
            LeagueSetup.saveDraftSettings(newDraftSettings);
        Test.stopTest();

        Draft_Settings__c insertedDraftSettings = Draft_Settings__c.getOrgDefaults();
        
        Assert.areEqual(10, insertedDraftSettings.Number_of_Rounds__c);
    }

    @isTest
    static void saveDraftSettings_Update() {
        Draft_Settings__c updatedDraftSettings = new Draft_Settings__c();
        updatedDraftSettings.Number_of_Rounds__c = 10;
        insert updatedDraftSettings;

        updatedDraftSettings.Number_of_Rounds__c = 15;

        Test.startTest();
        LeagueSetup.saveDraftSettings(updatedDraftSettings);
        Test.stopTest();

        Draft_Settings__c updatedRecord = Draft_Settings__c.getOrgDefaults();

        Assert.areEqual(updatedDraftSettings.Id, updatedRecord.Id, 'Did not update org defaults');
        Assert.areEqual(15, updatedRecord.Number_of_Rounds__c);
    }

    @isTest
    static void saveDraftSettings_Exception() {
        Draft_Settings__c updatedDraftSettings = new Draft_Settings__c();
        updatedDraftSettings.Name = 'This name is going to be too long to allow it to be saved properly. I need to keep typing to make sure this is an enormous amount of characters and therefore will definitely fail to insert properly. I cant think of any other way of ensuring that I hit the exception route to test it properly.';

        Boolean exceptionThrown = false;
        Test.startTest();
            try {
                LeagueSetup.saveDraftSettings(updatedDraftSettings);
            } catch(Exception e){
                exceptionThrown = true;
            }
        Test.stopTest();

        Assert.areEqual(true, exceptionThrown, 'An exception was not thrown as expected');
    }

    @isTest
    static void resetDraft_Success() {
        
        Player__c player = new Player__c();
        insert player;

        Team_Owner__c team = new Team_Owner__c();
        insert team;

        List<Pick__c> picks = new List<Pick__c>();
        for (Integer i = 0; i < 5; i++) {
            Pick__c pick = new Pick__c();
            pick.Player__c = player.Id;
            pick.Team_Owner__c = team.Id;
            picks.add(pick);
        }
        insert picks;

        List<Pick__c> remainingExistingPicks = [SELECT Id FROM Pick__c];

        Assert.areEqual(5, remainingExistingPicks.size());

        Test.startTest();
        LeagueSetup.resetDraft();
        Test.stopTest();

        List<Pick__c> remainingPicks = [SELECT Id FROM Pick__c];

        Assert.areEqual(0, remainingPicks.size());
    }

    //TODO: resetDraft fails
}
