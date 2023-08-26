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

        //TODO: add asserts
    }

    @IsTest
    static void getDraft_PicksMade_IsSnake(){
        //TODO: add picks to test against
        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        //TODO: add asserts
    }

    @IsTest
    static void getDraft_NoPicksMade_IsAuction(){
        Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
        settings.Draft_Type__c = 'auction';
        update settings;

        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        //TODO: add asserts
    }

    @IsTest
    static void getDraft_PicksMade_IsAuction(){
        //TODO: add picks

        Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
        settings.Draft_Type__c = 'auction';
        update settings;

        Test.startTest();
            ManageDraft.Draft draft = ManageDraft.getDraft();
        Test.stopTest();

        //TODO: add asserts
    }

}