public with sharing class ManageGuestUser {
    public class AuthResponse{
        String access_token;        
    }

    public static string getSessionId(){
        Logger.setScenario('Getting Session ID for use for Guest User');

        Self__c selfSettings = Self__c.getInstance();

        String url = selfSettings.URL__c;
        url += '?client_id=' + selfSettings.Client_Id__c;
        url += '&client_secret=' + selfSettings.Client_Secret__c;
        url += '&username=' + selfSettings.Username__c;
        url += '&password=' + selfSettings.Password__c;
        url += '&grant_type=' + selfSettings.Grant_Type__c;

        HttpResponse res = MFLRetrieveData.sfPostCallout(url);

        AuthResponse response = (AuthResponse)  JSON.deserialize(res.getBody(), AuthResponse.class);

        String sessionId = response.access_token;

        return sessionId;
    }
}