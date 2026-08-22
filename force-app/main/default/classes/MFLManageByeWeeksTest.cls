@IsTest
public class MFLManageByeWeeksTest {
  private class ByeWeekCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '{"nflByeWeeks":{"team":[{"id":"NE","bye_week":9},{"id":"KC","bye_week":6}]}}'
      );
      return res;
    }
  }

  private class InvalidTeamNameCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '{"nflByeWeeks":{"team":[{"id":"' +
          '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345' +
          '","bye_week":9}]}}'
      );
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
    mfl.Generic_URL__c = 'https://api.example.com';
    mfl.Year__c = '2026';
    insert mfl;
  }

  @IsTest
  static void manageByeWeeks_NewTeam_InsertsNewNFLTeam() {
    Test.setMock(HttpCalloutMock.class, new ByeWeekCalloutMock());

    Test.startTest();
    MFLManageByeWeeks.manageByeWeeks();
    Test.stopTest();

    List<NFL_Team__c> teams = [
      SELECT Name, Bye_Week__c
      FROM NFL_Team__c
      ORDER BY Name
    ];
    Assert.areEqual(2, teams.size());
    Assert.areEqual('KC', teams[0].Name);
    Assert.areEqual(6, teams[0].Bye_Week__c);
    Assert.areEqual('NE', teams[1].Name);
    Assert.areEqual(9, teams[1].Bye_Week__c);
  }

  @IsTest
  static void manageByeWeeks_ExistingTeamWithChangedByeWeek_UpdatesByeWeek() {
    NFL_Team__c existing = new NFL_Team__c(Name = 'NE', Bye_Week__c = 5);
    insert existing;

    Test.setMock(HttpCalloutMock.class, new ByeWeekCalloutMock());

    Test.startTest();
    MFLManageByeWeeks.manageByeWeeks();
    Test.stopTest();

    NFL_Team__c updated = [
      SELECT Bye_Week__c
      FROM NFL_Team__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(9, updated.Bye_Week__c);
  }

  @IsTest
  static void manageByeWeeks_ExistingTeamWithUnchangedByeWeek_NoUpdateNeeded() {
    NFL_Team__c existing = new NFL_Team__c(Name = 'NE', Bye_Week__c = 9);
    insert existing;
    Datetime originalLastModified = [
      SELECT LastModifiedDate
      FROM NFL_Team__c
      WHERE Id = :existing.Id
    ]
    .LastModifiedDate;

    Test.setMock(HttpCalloutMock.class, new ByeWeekCalloutMock());

    Test.startTest();
    MFLManageByeWeeks.manageByeWeeks();
    Test.stopTest();

    NFL_Team__c unchanged = [
      SELECT Bye_Week__c, LastModifiedDate
      FROM NFL_Team__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(9, unchanged.Bye_Week__c);
    Assert.areEqual(originalLastModified, unchanged.LastModifiedDate);
  }

  @IsTest
  static void manageByeWeeks_CalloutFails_ThrowsAuraHandledExceptionWithMFLErrorBody() {
    Test.setMock(HttpCalloutMock.class, new ErrorCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLManageByeWeeks.manageByeWeeks();
    } catch (AuraHandledException e) {
      exceptionThrown = true;
      Assert.isTrue(
        e.getMessage().contains('Internal Server Error'),
        'Expected the real MFL error body to reach the client, but was: ' +
        e.getMessage()
      );
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'An AuraHandledException should have been thrown when the callout fails'
    );
  }

  @IsTest
  static void manageByeWeeks_UpsertFails_ThrowsException() {
    Test.setMock(HttpCalloutMock.class, new InvalidTeamNameCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLManageByeWeeks.manageByeWeeks();
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'An exception should have been thrown when the upsert fails'
    );
  }

  @IsTest
  static void manageByeWeeks_MFLReturnsErrorEnvelope_ThrowsExceptionWithMFLsExactMessage() {
    Test.setMock(HttpCalloutMock.class, new MFLErrorEnvelopeCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLManageByeWeeks.manageByeWeeks();
    } catch (AuraHandledException e) {
      exceptionThrown = true;
      Assert.areEqual(
        'Invalid league ID 24312',
        e.getMessage(),
        'MFL\'s own error text should reach the client verbatim, not a guess'
      );
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'An exception should have been thrown when MFL returns an error envelope'
    );
  }

  @IsTest
  static void getNFLTeams_ExistingRecords_ReturnsMapKeyedByName() {
    NFL_Team__c team = new NFL_Team__c(Name = 'NE', Bye_Week__c = 9);
    insert team;

    Test.startTest();
    Map<String, NFL_Team__c> teams = MFLManageByeWeeks.getNFLTeams();
    Test.stopTest();

    Assert.areEqual(1, teams.size());
    Assert.isTrue(teams.containsKey('NE'));
    Assert.areEqual(team.Id, teams.get('NE').Id);
  }
}
