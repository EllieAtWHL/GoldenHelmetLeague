@IsTest
public class MFLManageOwnersTest {
  private class MFLCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');

      String endpoint = req.getEndpoint();
      if (endpoint.contains('TYPE=league')) {
        res.setBody(
          '{"league":{"franchises":{"franchise":[' +
            '{"id":"0001","name":"Test Team","owner_name":"Test Owner","icon":"https://example.com/icon.png"}' +
            ']}}}'
        );
      } else if (endpoint.contains('TYPE=draftResults')) {
        res.setBody(
          '{"draftResults":{"draftUnit":{"round1DraftOrder":"0001,0002"}}}'
        );
      } else {
        res.setBody('{}');
      }
      return res;
    }
  }

  private class MalformedLeagueCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"league":{}}');
      return res;
    }
  }

  @TestSetup
  static void makeData() {
    MFL__c mfl = new MFL__c();
    mfl.Instance_URL__c = 'https://instance.example.com';
    mfl.Year__c = '2026';
    mfl.League_Id__c = '12345';
    mfl.API_Key__c = 'testkey';
    insert mfl;
  }

  @IsTest
  static void manageOwners_NewFranchise_InsertsTeamOwner() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManageOwners.manageOwners();
    Test.stopTest();

    Team_Owner__c team = [
      SELECT Team_Name__c, Name__c, Franchise_Id__c, Icon_URL__c
      FROM Team_Owner__c
      WHERE Franchise_Id__c = '0001'
    ];
    Assert.areEqual('Test Team', team.Team_Name__c);
    Assert.areEqual('Test Owner', team.Name__c);
    Assert.areEqual('https://example.com/icon.png', team.Icon_URL__c);
  }

  @IsTest
  static void manageOwners_ExistingFranchiseChanged_UpdatesTeamOwner() {
    Team_Owner__c existing = new Team_Owner__c(
      Team_Name__c = 'Old Team Name',
      Name__c = 'Old Owner',
      Franchise_Id__c = '0001',
      Icon_URL__c = 'https://example.com/old-icon.png'
    );
    insert existing;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManageOwners.manageOwners();
    Test.stopTest();

    Team_Owner__c updated = [
      SELECT Team_Name__c, Name__c, Icon_URL__c
      FROM Team_Owner__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual('Test Team', updated.Team_Name__c);
    Assert.areEqual('Test Owner', updated.Name__c);
    Assert.areEqual('https://example.com/icon.png', updated.Icon_URL__c);
  }

  @IsTest
  static void manageOwners_ExistingFranchiseUnchanged_NoUpdateNeeded() {
    Team_Owner__c existing = new Team_Owner__c(
      Team_Name__c = 'Test Team',
      Name__c = 'Test Owner',
      Franchise_Id__c = '0001',
      Icon_URL__c = 'https://example.com/icon.png'
    );
    insert existing;
    Datetime originalLastModified = [
      SELECT LastModifiedDate
      FROM Team_Owner__c
      WHERE Id = :existing.Id
    ]
    .LastModifiedDate;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManageOwners.manageOwners();
    Test.stopTest();

    Team_Owner__c unchanged = [
      SELECT LastModifiedDate
      FROM Team_Owner__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(originalLastModified, unchanged.LastModifiedDate);
  }

  @IsTest
  static void manageOwners_SnakeDraft_SetsPickNumberFromDraftOrder() {
    Draft_Settings__c draftSettings = new Draft_Settings__c();
    draftSettings.Draft_Type__c = 'snake';
    insert draftSettings;

    // Pick_Number__c is only recalculated for franchises that already exist
    // as Team_Owner__c records, so seed one that the callout response will update.
    Team_Owner__c existing = new Team_Owner__c(
      Team_Name__c = 'Old Team Name',
      Franchise_Id__c = '0001'
    );
    insert existing;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManageOwners.manageOwners();
    Test.stopTest();

    Team_Owner__c team = [
      SELECT Pick_Number__c
      FROM Team_Owner__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(1, team.Pick_Number__c);
  }

  @IsTest
  static void manageOwners_MalformedResponse_ThrowsExceptionExplainingLikelyApiKeyIssue() {
    Test.setMock(HttpCalloutMock.class, new MalformedLeagueCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      MFLManageOwners.manageOwners();
    } catch (AuraHandledException e) {
      exceptionThrown = true;
      Assert.isTrue(
        e.getMessage().contains('API Key or League Id in League Setup'),
        'Exception message should point at the API Key/League Id as the likely cause, but was: ' +
        e.getMessage()
      );
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'An exception should have been thrown for a malformed response'
    );
  }

  @IsTest
  static void getTeams_ExistingRecords_ReturnsTeamsOrderedByPickNumber() {
    Team_Owner__c teamTwo = new Team_Owner__c(
      Team_Name__c = 'Team Two',
      Franchise_Id__c = '0002',
      Pick_Number__c = 2
    );
    Team_Owner__c teamOne = new Team_Owner__c(
      Team_Name__c = 'Team One',
      Franchise_Id__c = '0001',
      Pick_Number__c = 1
    );
    insert new List<Team_Owner__c>{ teamTwo, teamOne };

    Test.startTest();
    List<Team_Owner__c> teams = MFLManageOwners.getTeams();
    Test.stopTest();

    Assert.areEqual(2, teams.size());
    Assert.areEqual(teamOne.Id, teams[0].Id);
    Assert.areEqual(teamTwo.Id, teams[1].Id);
  }
}
