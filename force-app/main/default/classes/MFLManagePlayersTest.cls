@IsTest
public with sharing class MFLManagePlayersTest {
  private class MFLCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');

      String endpoint = req.getEndpoint();
      if (endpoint.contains('TYPE=players')) {
        res.setBody(
          '{"players":{"player":[{"id":"1000","name":"Test Player","team":"FA","position":"QB","status":"Active"}]}}'
        );
      } else if (endpoint.contains('TYPE=playerRanks')) {
        res.setBody('{"player_ranks":{"player":[{"id":"1000","rank":"3"}]}}');
      } else if (endpoint.contains('TYPE=adp')) {
        res.setBody(
          '{"adp":{"player":[{"id":"1000","rank":"5","averagePick":"4.5"}]}}'
        );
      } else if (endpoint.contains('TYPE=aav')) {
        res.setBody('{"aav":{"player":[{"id":"1000","averageValue":"50"}]}}');
      } else {
        res.setBody('{}');
      }
      return res;
    }
  }

  private class MFLCalloutMockNoAAVMatch implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');

      String endpoint = req.getEndpoint();
      if (endpoint.contains('TYPE=players')) {
        res.setBody(
          '{"players":{"player":[{"id":"1000","name":"Test Player","team":"FA","position":"QB","status":"Active"}]}}'
        );
      } else if (endpoint.contains('TYPE=playerRanks')) {
        res.setBody('{"player_ranks":{"player":[{"id":"1000","rank":"3"}]}}');
      } else if (endpoint.contains('TYPE=adp')) {
        res.setBody(
          '{"adp":{"player":[{"id":"1000","rank":"5","averagePick":"4.5"}]}}'
        );
      } else if (endpoint.contains('TYPE=aav')) {
        res.setBody('{"aav":{"player":[{"id":"9999","averageValue":"50"}]}}');
      } else {
        res.setBody('{}');
      }
      return res;
    }
  }

  @TestSetup
  static void makeData() {
    MFL__c mfl = new MFL__c();
    mfl.Generic_URL__c = 'https://api.example.com';
    mfl.Instance_URL__c = 'https://instance.example.com';
    mfl.Year__c = '2026';
    mfl.League_Id__c = '12345';
    mfl.API_Key__c = 'testkey';
    insert mfl;

    Draft_Settings__c draftSettings = new Draft_Settings__c();
    draftSettings.Auction_Budget__c = 200;
    insert draftSettings;

    List<Team_Owner__c> franchises = TestDataFactory.createFranchises(2);
    insert franchises;
  }

  @IsTest
  static void managePlayers_NewPlayer_ScalesPredictedAuctionCostToLeagueBudget() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    //averageValue 50 (per $1000 pool) * total league budget (200 * 2 franchises = 400) / 1000 = 20
    Player__c player = [
      SELECT
        Predicted_Auction_Cost__c,
        ADP_Average__c,
        ADP_Rank__c,
        Experts_Rank__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(20, player.Predicted_Auction_Cost__c);
    Assert.areEqual(4.5, player.ADP_Average__c);
    Assert.areEqual(5, player.ADP_Rank__c);
    Assert.areEqual(3, player.Experts_Rank__c);
  }

  @IsTest
  static void managePlayers_ExistingPlayerWithStaleCost_UpdatesPredictedAuctionCost() {
    Player__c existing = new Player__c(
      MFL_Id__c = '1000',
      MFL_Name__c = 'Test Player',
      Position__c = 'QB',
      MFL_Status__c = 'Active',
      ADP_Rank__c = 5,
      ADP_Average__c = 4.5,
      Experts_Rank__c = 3,
      Predicted_Auction_Cost__c = 10
    );
    insert existing;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c updated = [
      SELECT Predicted_Auction_Cost__c
      FROM Player__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(20, updated.Predicted_Auction_Cost__c);
  }

  @IsTest
  static void managePlayers_NoAuctionBudgetSet_PredictedAuctionCostDefaultsToZero() {
    Draft_Settings__c draftSettings = Draft_Settings__c.getOrgDefaults();
    draftSettings.Auction_Budget__c = null;
    update draftSettings;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c player = [
      SELECT Predicted_Auction_Cost__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(0, player.Predicted_Auction_Cost__c);
  }

  @IsTest
  static void managePlayers_NoFranchisesSetUp_PredictedAuctionCostDefaultsToZero() {
    delete [SELECT Id FROM Team_Owner__c];

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c player = [
      SELECT Predicted_Auction_Cost__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(0, player.Predicted_Auction_Cost__c);
  }

  @IsTest
  static void managePlayers_PlayerMissingFromAAVResponse_PredictedAuctionCostDefaultsToZero() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMockNoAAVMatch());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c player = [
      SELECT Predicted_Auction_Cost__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(0, player.Predicted_Auction_Cost__c);
  }

  @IsTest
  static void searchPlayers_NoSearchTerm_ReturnsTopAvailablePlayers() {
    Player__c player = new Player__c(
      MFL_Id__c = '1000',
      MFL_Name__c = 'Test Player',
      Position__c = 'QB',
      ADP_Rank__c = 1
    );
    insert player;

    Test.startTest();
    List<Player__c> results = MFLManagePlayers.searchPlayers(null);
    Test.stopTest();

    Assert.areEqual(1, results.size());
    Assert.areEqual(player.Id, results[0].Id);
  }
}
