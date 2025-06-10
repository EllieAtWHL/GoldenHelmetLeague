@IsTest
public with sharing class ManageDraftTest {

    @TestSetup
    static void makeData(){
        Draft_Settings__c settings = new Draft_Settings__c();
        settings.Draft_Type__c = 'snake';
        settings.Number_of_Rounds__c = 10;
        insert settings;
    }

    @IsTest
    static void getDraft_NoPicksMade_IsSnake(){
        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        Assert.areEqual('snake', draft.draftType);
        Assert.areEqual(10, draft.numberOfRounds);
        Assert.areEqual(10, draft.rounds.size());
    }

    @IsTest
    static void getDraft_PicksMade_IsSnake(){
        TestDataFactory.createTestDraft();

        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        Assert.areEqual('snake', draft.draftType);
        Assert.areEqual(10, draft.numberOfRounds);
        Assert.areEqual(10, draft.rounds.size());
        //TODO: Assert actual picks
    }

    @IsTest
    static void getDraft_NoPicksMade_IsAuction(){
        Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
        settings.Draft_Type__c = 'auction';
        update settings;

        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        Assert.areEqual('auction', draft.draftType);
        Assert.areEqual(17, draft.numberOfRounds);
        Assert.areEqual(17, draft.rounds.size());
    }

    @IsTest
    static void getDraft_PicksMade_IsAuction(){
        Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
        settings.Draft_Type__c = 'auction';
        update settings;
        TestDataFactory.createTestDraft();

        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        Assert.areEqual('auction', draft.draftType);
        Assert.areEqual(17, draft.numberOfRounds);
        Assert.areEqual(17, draft.rounds.size());
        //TODO: add asserts
    }

    @IsTest
    static void getPicks_NoPicksFound(){
        Test.startTest();
            Map<Integer, Pick__c> picks = ManageDraft.getPicks();
        Test.stopTest();

        Assert.areEqual(0, picks.size());
    }

    @IsTest
    static void getPicks_PicksFound(){
        TestDataFactory.createTestDraft();

        Test.startTest();
            Map<Integer, Pick__c> picks = ManageDraft.getPicks();
        Test.stopTest();

        Assert.areEqual(5, picks.size());
        for(Integer i=0; i<picks.size(); i++){
            Integer pickNumber = Integer.valueOf(picks.get(i+1).Overall_Pick_Number__c);
            Assert.areEqual(i+1, pickNumber);
        }
    }

    @IsTest
    static void makePick_SnakePick(){
        //TODO: Test a snake pick to be made
    }

    @IsTest
    static void makePick_AuctionPick(){
        //TODO: Test an auction pick to be made
    }

    @IsTest
    static void undoPick_Success(){
        //TODO: Test undoing a pick
    }

    @IsTest
    static void publishDraftUpdatedPlatformEvent_Success(){
        //TODO: Test publishing platform event for draftMessage
    }

    @IsTest
    static void publishDraftMessagePlatformEvent_Success(){
        //TODO: Test publishing platform event for draftMessage
    }

    @IsTest
    static void submitDraft_OK(){
        //TODO: Successful callout
    }

    @IsTest
    static void submitDraft_Fail(){
        //TODO: Failed callout
    }


    
}