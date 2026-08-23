@IsTest
public class ESPNRetrieveDataTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"status":"ok"}');
      return res;
    }
  }

  private class ErrorCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(500);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"error":"Internal Server Error"}');
      return res;
    }
  }

  private class ExceptionCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      throw new CalloutException('Simulated network failure');
    }
  }

  @IsTest
  static void espnGetCallout_Success_ReturnsResponse() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    HttpResponse res = ESPNRetrieveData.espnGetCallout(
      'https://site.api.espn.com/apis/site/v2/sports/football/nfl/injuries'
    );
    Test.stopTest();

    Assert.areEqual(200, res.getStatusCode());
    Assert.areEqual('{"status":"ok"}', res.getBody());
  }

  @IsTest
  static void espnGetCallout_NonSuccessStatusCode_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ErrorCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      ESPNRetrieveData.espnGetCallout(
        'https://site.api.espn.com/apis/site/v2/sports/football/nfl/injuries'
      );
    } catch (CalloutException e) {
      exceptionThrown = true;
      Assert.isTrue(
        e.getMessage().contains('Internal Server Error'),
        'Exception message should have contained the response body'
      );
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A CalloutException should have been thrown for a non-200 response'
    );
  }

  @IsTest
  static void espnGetCallout_CalloutFails_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ExceptionCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      ESPNRetrieveData.espnGetCallout(
        'https://site.api.espn.com/apis/site/v2/sports/football/nfl/injuries'
      );
    } catch (CalloutException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A CalloutException should have been thrown'
    );
  }
}
