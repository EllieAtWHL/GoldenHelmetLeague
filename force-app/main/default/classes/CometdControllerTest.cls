@IsTest
public with sharing class CometdControllerTest {
    @TestSetup
    static void makeData(){
    }

    @IsTest
    static void getSessionId_shouldReturnId_WhenUsingLoggedInUser(){
        String currentSessionId = UserInfo.getSessionId();
        
        Test.startTest();
            String obtainedSessionId = CometdController.getSessionId();
        Test.stopTest();

        Assert.areEqual(currentSessionId, obtainedSessionId, 'Incorrect session Id returned');
    }
    //TODO: Test guest user result for same method

    //TODO: Test getStoredSessionId

    //TODO: Test setStoredSessionId

    //TODO: Test error when storing session Id

}
