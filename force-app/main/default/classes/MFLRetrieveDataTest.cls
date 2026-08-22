@IsTest
public class MFLRetrieveDataTest {
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

  private class MFLErrorEnvelopeCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '{"encoding":"utf-8","version":"1.0","error":{"$t":"Invalid league ID 24312"}}'
      );
      return res;
    }
  }

  @TestSetup
  static void makeData() {
    MFL__c mfl = new MFL__c();
    mfl.MFL_User_Id__c = 'testMflUserId';
    insert mfl;
  }

  @IsTest
  static void sfPostCallout_Success_ReturnsResponse() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    HttpResponse res = MFLRetrieveData.sfPostCallout('https://api.example.com');
    Test.stopTest();

    Assert.areEqual(200, res.getStatusCode());
    Assert.areEqual('{"status":"ok"}', res.getBody());
  }

  @IsTest
  static void sfPostCallout_CalloutFails_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ExceptionCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLRetrieveData.sfPostCallout('https://api.example.com');
    } catch (CalloutException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A CalloutException should have been thrown'
    );
  }

  @IsTest
  static void mflGetCallout_Success_ReturnsResponse() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    HttpResponse res = MFLRetrieveData.mflGetCallout('https://api.example.com');
    Test.stopTest();

    Assert.areEqual(200, res.getStatusCode());
    Assert.areEqual('{"status":"ok"}', res.getBody());
  }

  @IsTest
  static void mflGetCallout_ErrorEnvelopeWith200Status_ThrowsMFLApiExceptionWithMFLsOwnMessage() {
    Test.setMock(HttpCalloutMock.class, new MFLErrorEnvelopeCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLRetrieveData.mflGetCallout('https://api.example.com');
    } catch (MFLApiException e) {
      exceptionThrown = true;
      Assert.areEqual(
        'Invalid league ID 24312',
        e.getMessage(),
        'MFL\'s own error text should be used as the exception message verbatim'
      );
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'An MFLApiException should have been thrown for a 200 response containing an error envelope'
    );
  }

  @IsTest
  static void mflGetCallout_SuccessBodyWithNoErrorKey_DoesNotThrow() {
    // Guards against the error-envelope detection misfiring on a normal
    // response that simply doesn't happen to contain an "error" key.
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    HttpResponse res = MFLRetrieveData.mflGetCallout('https://api.example.com');
    Test.stopTest();

    Assert.areEqual(200, res.getStatusCode());
  }

  @IsTest
  static void mflGetCallout_NonSuccessStatusCode_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ErrorCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLRetrieveData.mflGetCallout('https://api.example.com');
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
  static void mflGetCallout_CalloutFails_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ExceptionCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLRetrieveData.mflGetCallout('https://api.example.com');
    } catch (CalloutException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A CalloutException should have been thrown'
    );
  }

  @IsTest
  static void mflPostCallout_Success_ReturnsResponse() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    HttpResponse res = MFLRetrieveData.mflPostCallout(
      'https://api.example.com',
      'draft results payload'
    );
    Test.stopTest();

    Assert.areEqual(200, res.getStatusCode());
    Assert.areEqual('{"status":"ok"}', res.getBody());
  }

  @IsTest
  static void mflPostCallout_NonSuccessStatusCode_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ErrorCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLRetrieveData.mflPostCallout(
        'https://api.example.com',
        'draft results payload'
      );
    } catch (CalloutException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A CalloutException should have been thrown for a non-200 response'
    );
  }

  @IsTest
  static void mflPostCallout_CalloutFails_ThrowsCalloutException() {
    Test.setMock(HttpCalloutMock.class, new ExceptionCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLRetrieveData.mflPostCallout(
        'https://api.example.com',
        'draft results payload'
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
