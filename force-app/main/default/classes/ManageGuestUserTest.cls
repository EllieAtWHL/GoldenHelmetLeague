@IsTest
public class ManageGuestUserTest {
  private class AuthCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"access_token":"testAccessToken"}');
      return res;
    }
  }

  @TestSetup
  static void makeData() {
    Self__c selfSettings = new Self__c();
    selfSettings.URL__c = 'https://login.example.com/services/oauth2/token';
    selfSettings.Client_Id__c = 'testClientId';
    selfSettings.Client_Secret__c = 'testClientSecret';
    selfSettings.Username__c = 'testUsername';
    selfSettings.Password__c = 'testPassword';
    selfSettings.Grant_Type__c = 'password';
    insert selfSettings;
  }

  @IsTest
  static void getSessionId_Success_ReturnsAccessToken() {
    Test.setMock(HttpCalloutMock.class, new AuthCalloutMock());

    Test.startTest();
    String sessionId = ManageGuestUser.getSessionId();
    Test.stopTest();

    Assert.areEqual(
      'testAccessToken',
      sessionId,
      'The access token from the callout response should have been returned'
    );
  }
}
