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

  private class MFLCalloutMockUntrackedPosition implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');

      String endpoint = req.getEndpoint();
      if (endpoint.contains('TYPE=players')) {
        // Same player id as MFLCalloutMock, but tagged with a position (LB)
        // that isn't in the Position__c picklist - MFL's players export
        // includes every NFL player, not just fantasy-relevant ones.
        res.setBody(
          '{"players":{"player":[{"id":"1000","name":"Test Player","team":"FA","position":"LB","status":"Active"}]}}'
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
  static void managePlayers_NewPlayer_ScalesPredictedAuctionCostToPerTeamBudget() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    // averageValue 50 (per $1000 notional per-team budget) * this league's
    // per-team budget (200) / 1000 = 10. Franchise count must NOT factor in
    // here - a player's cost is bounded by one team's budget, not the
    // combined pool of every team in the league.
    Player__c player = [
      SELECT
        MFL_AAV__c,
        Predicted_Auction_Cost__c,
        ADP_Average__c,
        ADP_Rank__c,
        Experts_Rank__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(50, player.MFL_AAV__c);
    Assert.areEqual(10, player.Predicted_Auction_Cost__c);
    Assert.areEqual(4.5, player.ADP_Average__c);
    Assert.areEqual(5, player.ADP_Rank__c);
    Assert.areEqual(3, player.Experts_Rank__c);
  }

  @IsTest
  static void managePlayers_ExistingPlayerWithStaleAAV_UpdatesAAVAndPredictedCost() {
    Player__c existing = new Player__c(
      MFL_Id__c = '1000',
      MFL_Name__c = 'Test Player',
      Position__c = 'QB',
      MFL_Status__c = 'Active',
      ADP_Rank__c = 5,
      ADP_Average__c = 4.5,
      Experts_Rank__c = 3,
      MFL_AAV__c = 25
    );
    insert existing;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c updated = [
      SELECT MFL_AAV__c, Predicted_Auction_Cost__c
      FROM Player__c
      WHERE Id = :existing.Id
    ];
    Assert.areEqual(50, updated.MFL_AAV__c);
    Assert.areEqual(10, updated.Predicted_Auction_Cost__c);
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
  static void managePlayers_PlayerMissingFromAAVResponse_PredictedAuctionCostDefaultsToZero() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMockNoAAVMatch());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c player = [
      SELECT MFL_AAV__c, Predicted_Auction_Cost__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.isNull(player.MFL_AAV__c);
    Assert.areEqual(0, player.Predicted_Auction_Cost__c);
  }

  @IsTest
  static void managePlayers_UndraftedPlayerNoLongerInMFLResponse_DeletesPlayer() {
    Player__c staleplayer = new Player__c(
      MFL_Id__c = '9999',
      MFL_Name__c = 'Retired Player',
      Position__c = 'QB'
    );
    insert staleplayer;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    List<Player__c> remaining = [
      SELECT Id
      FROM Player__c
      WHERE Id = :staleplayer.Id
    ];
    Assert.isTrue(
      remaining.isEmpty(),
      'A player no longer returned by MFL should have been deleted'
    );
  }

  @IsTest
  static void managePlayers_DraftedPlayerNoLongerInMFLResponse_IsNotDeleted() {
    Team_Owner__c team = [SELECT Id FROM Team_Owner__c LIMIT 1];
    Player__c draftedPlayer = new Player__c(
      MFL_Id__c = '9999',
      MFL_Name__c = 'Drafted Player',
      Position__c = 'QB',
      Team_Owner__c = team.Id
    );
    insert draftedPlayer;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    List<Player__c> remaining = [
      SELECT Id
      FROM Player__c
      WHERE Id = :draftedPlayer.Id
    ];
    Assert.areEqual(
      1,
      remaining.size(),
      'A drafted player should never be deleted, even if MFL no longer returns them'
    );
  }

  @IsTest
  static void managePlayers_UndraftedPlayerPositionNoLongerTrackedByLeague_DeletesPlayer() {
    Player__c existing = new Player__c(
      MFL_Id__c = '1000',
      MFL_Name__c = 'Test Player',
      Position__c = 'QB'
    );
    insert existing;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMockUntrackedPosition());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    List<Player__c> remaining = [
      SELECT Id
      FROM Player__c
      WHERE Id = :existing.Id
    ];
    Assert.isTrue(
      remaining.isEmpty(),
      'A player whose MFL position is no longer tracked by this league should be deleted'
    );
  }

  @IsTest
  static void managePlayers_DraftedPlayerPositionNoLongerTrackedByLeague_IsNotDeleted() {
    Team_Owner__c team = [SELECT Id FROM Team_Owner__c LIMIT 1];
    Player__c draftedPlayer = new Player__c(
      MFL_Id__c = '1000',
      MFL_Name__c = 'Drafted Player',
      Position__c = 'QB',
      Team_Owner__c = team.Id
    );
    insert draftedPlayer;

    Test.setMock(HttpCalloutMock.class, new MFLCalloutMockUntrackedPosition());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    List<Player__c> remaining = [
      SELECT Id
      FROM Player__c
      WHERE Id = :draftedPlayer.Id
    ];
    Assert.areEqual(
      1,
      remaining.size(),
      'A drafted player should never be deleted, even if their MFL position is no longer tracked'
    );
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
