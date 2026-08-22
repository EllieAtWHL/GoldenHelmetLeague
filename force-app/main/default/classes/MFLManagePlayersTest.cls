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
        res.setBody(
          '{"aav":{"player":[{"id":"1000","averageValue":"50","minValue":"35","maxValue":"65"}]}}'
        );
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
  static void managePlayers_NewPlayer_ScalesPredictedAuctionCostToLeagueWideBudgetPool() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    // MFL's averageValue of 50 is relative to a $1000 pool shared across
    // the WHOLE league (per MFL's own API docs), not one team's budget -
    // so it scales against this league's combined pool: 2 franchises (see
    // @TestSetup) * this league's per-team budget (200) = $400 total.
    // 50 / 1000 * 400 = 20.
    Player__c player = [
      SELECT
        MFL_AAV__c,
        AAV_Min__c,
        AAV_Max__c,
        Predicted_Auction_Cost__c,
        ADP_Average__c,
        ADP_Rank__c,
        Experts_Rank__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(50, player.MFL_AAV__c);
    Assert.areEqual(35, player.AAV_Min__c);
    Assert.areEqual(65, player.AAV_Max__c);
    Assert.areEqual(20, player.Predicted_Auction_Cost__c);
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
    Assert.areEqual(20, updated.Predicted_Auction_Cost__c);
  }

  @IsTest
  static void predictedAuctionCost_ScalesAgainstLeagueWidePool_NotJustOneTeamsBudget() {
    // Per MFL's own API docs, an averageValue of 1000 is relative to a
    // $1000 pool shared across the WHOLE league, not one team's budget.
    // A 10-team, $200/team league's real combined pool is $2000, so an
    // average value of 500 (half the notional pool) should cost half of
    // that real pool: $1000 - not half of a single team's $200 budget.
    Decimal cost = MFLManagePlayers.predictedAuctionCost(500, 200, 10);

    Assert.areEqual(1000, cost);
  }

  @IsTest
  static void predictedAuctionCost_DifferentTeamCounts_ScaleProportionally() {
    Decimal costFor4Teams = MFLManagePlayers.predictedAuctionCost(100, 200, 4);
    Decimal costFor8Teams = MFLManagePlayers.predictedAuctionCost(100, 200, 8);

    Assert.areEqual(
      costFor8Teams,
      costFor4Teams * 2,
      'Doubling the league size should double the predicted cost for the same MFL-normalized value and per-team budget'
    );
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
    Assert.areEqual(0, player.MFL_AAV__c);
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

  private static void insertWRPlayersWithCorrelatedRankAndAAV() {
    // ADP_Rank__c and MFL_AAV__c are deliberately correlated (better rank
    // <-> higher AAV) and both have the same shape: three players close
    // together, a big jump, then three more players close together. That
    // jump (47 in rank, 80 in AAV) is far larger than the ~5-point gaps
    // around it - comfortably past mean + 1 stddev for both metrics - so
    // both Tier_Rank__c and Tier_Auction__c should split 1/1/1/2/2/2.
    List<Player__c> players = new List<Player__c>{
      new Player__c(
        MFL_Id__c = '1',
        MFL_Name__c = 'WR Rank1',
        Position__c = 'WR',
        ADP_Rank__c = 1,
        MFL_AAV__c = 100
      ),
      new Player__c(
        MFL_Id__c = '2',
        MFL_Name__c = 'WR Rank2',
        Position__c = 'WR',
        ADP_Rank__c = 2,
        MFL_AAV__c = 95
      ),
      new Player__c(
        MFL_Id__c = '3',
        MFL_Name__c = 'WR Rank3',
        Position__c = 'WR',
        ADP_Rank__c = 3,
        MFL_AAV__c = 90
      ),
      new Player__c(
        MFL_Id__c = '4',
        MFL_Name__c = 'WR Rank50',
        Position__c = 'WR',
        ADP_Rank__c = 50,
        MFL_AAV__c = 10
      ),
      new Player__c(
        MFL_Id__c = '5',
        MFL_Name__c = 'WR Rank51',
        Position__c = 'WR',
        ADP_Rank__c = 51,
        MFL_AAV__c = 8
      ),
      new Player__c(
        MFL_Id__c = '6',
        MFL_Name__c = 'WR Rank52',
        Position__c = 'WR',
        ADP_Rank__c = 52,
        MFL_AAV__c = 5
      )
    };
    insert players;
  }

  @IsTest
  static void computeTiers_LargeGapWithinPosition_SplitsGroupAcrossThatGap() {
    insertWRPlayersWithCorrelatedRankAndAAV();

    Test.startTest();
    MFLManagePlayers.computeTiers();
    Test.stopTest();

    Map<String, Player__c> byMflId = new Map<String, Player__c>();
    for (Player__c player : [
      SELECT MFL_Id__c, Tier_Rank__c, Tier_Auction__c
      FROM Player__c
    ]) {
      byMflId.put(player.MFL_Id__c, player);
    }

    Assert.areEqual(1, byMflId.get('1').Tier_Rank__c);
    Assert.areEqual(1, byMflId.get('2').Tier_Rank__c);
    Assert.areEqual(1, byMflId.get('3').Tier_Rank__c);
    Assert.areEqual(2, byMflId.get('4').Tier_Rank__c);
    Assert.areEqual(2, byMflId.get('5').Tier_Rank__c);
    Assert.areEqual(2, byMflId.get('6').Tier_Rank__c);

    Assert.areEqual(1, byMflId.get('1').Tier_Auction__c);
    Assert.areEqual(1, byMflId.get('2').Tier_Auction__c);
    Assert.areEqual(1, byMflId.get('3').Tier_Auction__c);
    Assert.areEqual(2, byMflId.get('4').Tier_Auction__c);
    Assert.areEqual(2, byMflId.get('5').Tier_Auction__c);
    Assert.areEqual(2, byMflId.get('6').Tier_Auction__c);
  }

  @IsTest
  static void computeTiers_ManySentinelPlayersInGroup_DoesNotCorruptTieringAmongRealPlayers() {
    // Mirrors the real WR case this was built for: a position group is
    // mostly players with no real rank data (unranked entirely) or no
    // real auction interest ($0 AAV). Without excluding those sentinel
    // values from the gap-detection statistics, one huge jump up to the
    // rank sentinel inflates the standard deviation so much that real
    // gaps never look large by comparison (dumping almost the whole
    // position into tier 1), while a sea of $0 gaps between bench
    // players shrinks the average auction gap toward zero (making small
    // real gaps between stars look enormous, splitting them into a tier
    // apiece). The same six real players and 1,2,3 / 50,51,52 split as
    // computeTiers_LargeGapWithinPosition...  above should still split
    // 1,1,1,2,2,2 even with 20 "no data" players mixed into the group.
    List<Player__c> players = new List<Player__c>{
      new Player__c(
        MFL_Id__c = '1',
        MFL_Name__c = 'Real Rank1',
        Position__c = 'WR',
        ADP_Rank__c = 1,
        MFL_AAV__c = 100
      ),
      new Player__c(
        MFL_Id__c = '2',
        MFL_Name__c = 'Real Rank2',
        Position__c = 'WR',
        ADP_Rank__c = 2,
        MFL_AAV__c = 95
      ),
      new Player__c(
        MFL_Id__c = '3',
        MFL_Name__c = 'Real Rank3',
        Position__c = 'WR',
        ADP_Rank__c = 3,
        MFL_AAV__c = 90
      ),
      new Player__c(
        MFL_Id__c = '4',
        MFL_Name__c = 'Real Rank50',
        Position__c = 'WR',
        ADP_Rank__c = 50,
        MFL_AAV__c = 10
      ),
      new Player__c(
        MFL_Id__c = '5',
        MFL_Name__c = 'Real Rank51',
        Position__c = 'WR',
        ADP_Rank__c = 51,
        MFL_AAV__c = 8
      ),
      new Player__c(
        MFL_Id__c = '6',
        MFL_Name__c = 'Real Rank52',
        Position__c = 'WR',
        ADP_Rank__c = 52,
        MFL_AAV__c = 5
      )
    };
    for (Integer i = 0; i < 20; i++) {
      players.add(
        new Player__c(
          MFL_Id__c = 'n' + i,
          MFL_Name__c = 'No Data ' + i,
          Position__c = 'WR'
          // ADP_Rank__c/MFL_AAV__c left unset - defaults to the rank
          // (9999) and auction ($0) sentinels via metricValue().
        )
      );
    }
    insert players;

    Test.startTest();
    MFLManagePlayers.computeTiers();
    Test.stopTest();

    Map<String, Player__c> byMflId = new Map<String, Player__c>();
    for (Player__c player : [
      SELECT MFL_Id__c, Tier_Rank__c, Tier_Auction__c
      FROM Player__c
      WHERE MFL_Id__c IN ('1', '2', '3', '4', '5', '6')
    ]) {
      byMflId.put(player.MFL_Id__c, player);
    }

    Assert.areEqual(1, byMflId.get('1').Tier_Rank__c);
    Assert.areEqual(1, byMflId.get('2').Tier_Rank__c);
    Assert.areEqual(1, byMflId.get('3').Tier_Rank__c);
    Assert.areEqual(2, byMflId.get('4').Tier_Rank__c);
    Assert.areEqual(2, byMflId.get('5').Tier_Rank__c);
    Assert.areEqual(2, byMflId.get('6').Tier_Rank__c);

    Assert.areEqual(1, byMflId.get('1').Tier_Auction__c);
    Assert.areEqual(1, byMflId.get('2').Tier_Auction__c);
    Assert.areEqual(1, byMflId.get('3').Tier_Auction__c);
    Assert.areEqual(2, byMflId.get('4').Tier_Auction__c);
    Assert.areEqual(2, byMflId.get('5').Tier_Auction__c);
    Assert.areEqual(2, byMflId.get('6').Tier_Auction__c);
  }

  @IsTest
  static void computeTiers_EvenlySpacedPosition_StaysInOneTier() {
    List<Player__c> players = new List<Player__c>();
    for (Integer i = 1; i <= 6; i++) {
      players.add(
        new Player__c(
          MFL_Id__c = String.valueOf(i),
          MFL_Name__c = 'QB Rank' + i,
          Position__c = 'QB',
          ADP_Rank__c = i,
          MFL_AAV__c = 100 - i
        )
      );
    }
    insert players;

    Test.startTest();
    MFLManagePlayers.computeTiers();
    Test.stopTest();

    for (Player__c player : [
      SELECT Tier_Rank__c, Tier_Auction__c
      FROM Player__c
    ]) {
      Assert.areEqual(
        1,
        player.Tier_Rank__c,
        'Uniform gaps should never exceed the tier-break threshold'
      );
      Assert.areEqual(1, player.Tier_Auction__c);
    }
  }

  @IsTest
  static void computeTiers_MultiplePositions_ComputedIndependentlyPerPosition() {
    insertWRPlayersWithCorrelatedRankAndAAV();
    Player__c soleQB = new Player__c(
      MFL_Id__c = '7',
      MFL_Name__c = 'Lone QB',
      Position__c = 'QB',
      ADP_Rank__c = 200,
      MFL_AAV__c = 1
    );
    insert soleQB;

    Test.startTest();
    MFLManagePlayers.computeTiers();
    Test.stopTest();

    Player__c updatedQB = [
      SELECT Tier_Rank__c, Tier_Auction__c
      FROM Player__c
      WHERE Id = :soleQB.Id
    ];
    Assert.areEqual(
      1,
      updatedQB.Tier_Rank__c,
      'A position group with only one player is trivially its own tier 1, unaffected by other positions'
    );
    Assert.areEqual(1, updatedQB.Tier_Auction__c);
  }

  @IsTest
  static void computeTiers_PlayerWithNullRankAndAAV_TreatedAsWorstInGroup() {
    // ADP_Rank__c, Experts_Rank__c and MFL_AAV__c are all optional at the
    // schema level - createPlayer() always populates them for anything
    // synced from MFL, but a manually-created or legacy record can have
    // them null. This must not blow up gap detection for the rest of the
    // position group (it did before metricValue() was added - a null
    // caused a NullPointerException computing the gap against its
    // neighbour), and the incomplete player should land in the worst
    // tier, consistent with how createPlayer()/getRawAAV() already treat
    // a player MFL doesn't return a value for.
    Player__c incompletePlayer = new Player__c(
      MFL_Id__c = '1',
      MFL_Name__c = 'No Rank Data',
      Position__c = 'QB'
    );
    Player__c rankedPlayer = new Player__c(
      MFL_Id__c = '2',
      MFL_Name__c = 'Has Rank Data',
      Position__c = 'QB',
      ADP_Rank__c = 1,
      MFL_AAV__c = 100
    );
    insert new List<Player__c>{ incompletePlayer, rankedPlayer };

    Test.startTest();
    MFLManagePlayers.computeTiers();
    Test.stopTest();

    Map<String, Player__c> byMflId = new Map<String, Player__c>();
    for (Player__c player : [
      SELECT MFL_Id__c, Tier_Rank__c, Tier_Auction__c
      FROM Player__c
    ]) {
      byMflId.put(player.MFL_Id__c, player);
    }

    Assert.areEqual(1, byMflId.get('2').Tier_Rank__c);
    Assert.areEqual(1, byMflId.get('2').Tier_Auction__c);
    Assert.isTrue(
      byMflId.get('1').Tier_Rank__c >= byMflId.get('2').Tier_Rank__c,
      'A player with no rank data should never be tiered ahead of a player with real data'
    );
    Assert.isTrue(
      byMflId.get('1').Tier_Auction__c >= byMflId.get('2').Tier_Auction__c,
      'A player with no AAV data should never be tiered ahead of a player with real data'
    );
  }

  @IsTest
  static void expertWeightedRankValues_BlendsBothRanks_LeaningTowardExperts() {
    Player__c player = new Player__c(
      MFL_Id__c = '1',
      MFL_Name__c = 'Test Player',
      Position__c = 'QB',
      ADP_Rank__c = 10,
      Experts_Rank__c = 100
    );
    insert player;

    Map<Id, Decimal> blended = MFLManagePlayers.expertWeightedRankValues(
      new List<Player__c>{ player }
    );

    // 0.65*100 (experts) + 0.35*10 (ADP) = 65 + 3.5 = 68.5 - much closer
    // to the experts rank (100) than a straight average (55) would be.
    Assert.areEqual(68.5, blended.get(player.Id));
  }

  @IsTest
  static void expertWeightedRankValues_MissingExpertsRank_DefaultsToWorstSentinel() {
    // Mirrors metricValue()'s existing convention for a player MFL
    // doesn't return a rank for.
    Player__c player = new Player__c(
      MFL_Id__c = '1',
      MFL_Name__c = 'Test Player',
      Position__c = 'QB',
      ADP_Rank__c = 10
    );
    insert player;

    Map<Id, Decimal> blended = MFLManagePlayers.expertWeightedRankValues(
      new List<Player__c>{ player }
    );

    // 0.65*9999 + 0.35*10 = 6499.35 + 3.5 = 6502.85
    Assert.areEqual(6502.85, blended.get(player.Id));
  }

  @IsTest
  static void auctionValueConfidence_TightSpread_ReturnsHighConfidence() {
    // spread (115-85=30) / average (100) = 0.3; confidence = 1 - 0.3/2 = 0.85
    Player__c player = new Player__c(
      MFL_AAV__c = 100,
      AAV_Min__c = 85,
      AAV_Max__c = 115
    );

    Decimal confidence = MFLManagePlayers.auctionValueConfidence(player, 100);

    Assert.areEqual(0.85, confidence);
  }

  @IsTest
  static void auctionValueConfidence_SpreadWiderThanScale_ClampsToZero() {
    // spread (400-0=400) / average (100) = 4.0, past SPREAD_CONFIDENCE_SCALE
    // (2.0) - would go negative unclamped, so this also verifies the floor.
    Player__c player = new Player__c(
      MFL_AAV__c = 100,
      AAV_Min__c = 0,
      AAV_Max__c = 400
    );

    Decimal confidence = MFLManagePlayers.auctionValueConfidence(player, 100);

    Assert.areEqual(0, confidence);
  }

  @IsTest
  static void auctionValueConfidence_ZeroAverage_ReturnsZero() {
    Player__c player = new Player__c(
      MFL_AAV__c = 0,
      AAV_Min__c = 0,
      AAV_Max__c = 0
    );

    Decimal confidence = MFLManagePlayers.auctionValueConfidence(player, 0);

    Assert.areEqual(0, confidence);
  }

  @IsTest
  static void auctionValueConfidence_NoSpreadDataYet_DefaultsToFullConfidence() {
    // A player synced before AAV_Min__c/AAV_Max__c existed, or whose AAV
    // hasn't changed since (so createPlayer() had no reason to rewrite
    // it), won't have spread data. That's an absence of evidence, not
    // evidence of unreliability - should trust the average as-is, same
    // as before this feature existed, rather than guessing at either
    // extreme.
    Player__c player = new Player__c(MFL_AAV__c = 100);

    Decimal confidence = MFLManagePlayers.auctionValueConfidence(player, 100);

    Assert.areEqual(1, confidence);
  }

  @IsTest
  static void confidenceAdjustedAuctionValues_WideSpreadOutlier_CanRankBelowATighterLowerRawValue() {
    // Mirrors the real scenario this was built for: a hyped, rarely-agreed-on
    // player (highest raw AAV, but a huge min/max spread) versus an
    // established player the market broadly agrees on (lower raw AAV, tight
    // spread). The volatile player's raw number alone would rank it first;
    // confidence-adjustment should pull it back below the reliable one.
    Player__c reliableFavourite = new Player__c(
      MFL_Id__c = '1',
      MFL_Name__c = 'Reliable Favourite',
      Position__c = 'QB',
      MFL_AAV__c = 42,
      AAV_Min__c = 37,
      AAV_Max__c = 47 // spread 10 / avg 42 -> confidence ~0.92, barely shrinks
    );
    Player__c volatileOutlier = new Player__c(
      MFL_Id__c = '2',
      MFL_Name__c = 'Volatile Outlier',
      Position__c = 'QB',
      MFL_AAV__c = 45,
      AAV_Min__c = 0,
      AAV_Max__c = 135 // spread 135 / avg 45 = 3.0, past SPREAD_CONFIDENCE_SCALE (2.0) -> confidence 0, fully discounted to the group median
    );
    Player__c thirdPlayer = new Player__c(
      MFL_Id__c = '3',
      MFL_Name__c = 'Reliable Third',
      Position__c = 'QB',
      MFL_AAV__c = 20,
      AAV_Min__c = 17,
      AAV_Max__c = 23
    );
    Player__c fourthPlayer = new Player__c(
      MFL_Id__c = '4',
      MFL_Name__c = 'Reliable Fourth',
      Position__c = 'QB',
      MFL_AAV__c = 18,
      AAV_Min__c = 15,
      AAV_Max__c = 21
    );
    List<Player__c> positionGroup = new List<Player__c>{
      reliableFavourite,
      volatileOutlier,
      thirdPlayer,
      fourthPlayer
    };
    insert positionGroup; // confidenceAdjustedAuctionValues() keys its result by Id

    Map<Id, Decimal> adjustedValues = MFLManagePlayers.confidenceAdjustedAuctionValues(
      positionGroup
    );

    // Group of 4 is smaller than MIN_NEIGHBORHOOD_SAMPLE_SIZE (5), so the
    // window can't expand any further than the whole group. Of the 4,
    // only volatileOutlier itself falls below CONFIDENT_NEIGHBOR_THRESHOLD
    // (its own confidence clamps to 0) - the other 3 (42/20/18) all clear
    // it and MIN_CONFIDENT_NEIGHBOR_SAMPLE_SIZE (3) is met, so the anchor
    // is their median (20), not the full group's (31).
    Assert.areEqual(
      20,
      adjustedValues.get(volatileOutlier.Id),
      'A fully-discounted player (confidence 0) should land exactly on the confident-neighbour median'
    );
    Assert.isTrue(
      adjustedValues.get(volatileOutlier.Id) <
      adjustedValues.get(reliableFavourite.Id),
      'The volatile outlier has the highest raw AAV (45) but should rank below the tighter-spread player (42, adjusted ~37.1) once confidence-adjusted'
    );
    Assert.isTrue(
      adjustedValues.get(volatileOutlier.Id) < 45,
      'A heavily-discounted player should be pulled below its own raw value, toward the group median'
    );
  }

  @IsTest
  static void confidenceAdjustedAuctionValues_OutlierNearTopOfRank_AnchorsAgainstNearbyPlayersNotWholeGroup() {
    // Mirrors the real case this was built for: a player ranked among
    // the best at their position whose raw AAV is many times higher
    // than even the best-ranked players near them - not because the
    // position's replacement-level bench players make it look extreme
    // (a position-wide median would say that), but because it's out of
    // line with what OTHER similarly-ranked players actually go for.
    List<Decimal> eliteRawValues = new List<Decimal>{
      25,
      22,
      90,
      19,
      17,
      16,
      15,
      14,
      13,
      12
    };
    List<Player__c> positionGroup = new List<Player__c>();
    for (Integer i = 0; i < eliteRawValues.size(); i++) {
      Decimal raw = eliteRawValues[i];
      Player__c player = (i == 2)
        ? new Player__c(
            MFL_Id__c = 'out',
            MFL_Name__c = 'Outlier',
            Position__c = 'QB',
            MFL_AAV__c = raw,
            AAV_Min__c = 5,
            AAV_Max__c = 175 // spread 170 / avg 90 = 1.889 -> confidence ~0.056, almost fully distrusted
          )
        : new Player__c(
            MFL_Id__c = 'e' + i,
            MFL_Name__c = 'Elite ' + i,
            Position__c = 'QB',
            MFL_AAV__c = raw,
            AAV_Min__c = raw - 2,
            AAV_Max__c = raw + 2
          );
      positionGroup.add(player);
    }
    // 15 replacement-level players, ranked well below the elites
    // (indices 10-24) - well outside the outlier's +-7 rank
    // neighbourhood (RANK_NEIGHBORHOOD_SIZE), present only to drag the
    // whole-group median down and prove it's NOT what the outlier gets
    // anchored against.
    for (Integer i = 0; i < 15; i++) {
      positionGroup.add(
        new Player__c(
          MFL_Id__c = 'r' + i,
          MFL_Name__c = 'Replacement ' + i,
          Position__c = 'QB',
          MFL_AAV__c = 2,
          AAV_Min__c = 1,
          AAV_Max__c = 3
        )
      );
    }
    insert positionGroup; // confidenceAdjustedAuctionValues() keys its result by Id

    Map<Id, Decimal> adjustedValues = MFLManagePlayers.confidenceAdjustedAuctionValues(
      positionGroup
    );
    Decimal outlierAdjusted = adjustedValues.get(positionGroup[2].Id);

    // Local median of the elite window (25,22,19,17,16,15,14,13,12) is
    // 16.5, giving an adjusted value of ~20.6. A whole-group median
    // (dragged to 2 by the 15 replacement players) would have produced
    // only ~6.9 - well under 15 either way, so this bound cleanly
    // distinguishes the two approaches without depending on exact
    // decimal precision.
    Assert.isTrue(
      outlierAdjusted > 15,
      'Anchored against its own rank neighbourhood, not the whole position, the outlier should land near its local median (~16.5) rather than a global one dragged down by replacement players (~2)'
    );
    Assert.isTrue(
      outlierAdjusted < 90,
      'Still meaningfully discounted from its own raw value given how low confidence is'
    );
  }

  @IsTest
  static void confidenceAdjustedAuctionValues_SparseNeighborhood_ExpandsWindowInsteadOfTrustingTinySample() {
    // Mirrors the real case this was built for: a deep-bench player's
    // immediate rank neighbourhood has almost no real (nonzero) AAV data
    // - just one or two other low-confidence prices, since everyone else
    // nearby is a $0 bench player. A median of just those one or two
    // noisy neighbours takes their own inflated prices at face value.
    // Widening the window until it finds MIN_NEIGHBORHOOD_SAMPLE_SIZE (5)
    // real prices instead pulls in enough genuinely low-value players
    // (further down the rank order but still real data) to produce a
    // robust, low anchor instead.
    List<Player__c> players = new List<Player__c>();
    players.add(
      new Player__c(
        MFL_Id__c = 'real1',
        MFL_Name__c = 'Real Neighbour 1',
        Position__c = 'QB',
        MFL_AAV__c = 10,
        AAV_Min__c = 8,
        AAV_Max__c = 12
      )
    );
    players.add(
      new Player__c(
        MFL_Id__c = 'out',
        MFL_Name__c = 'Sparse Outlier',
        Position__c = 'QB',
        MFL_AAV__c = 90,
        AAV_Min__c = 0,
        AAV_Max__c = 270 // spread 270 / avg 90 = 3.0, past scale -> confidence 0, so its own price contributes nothing to its own adjusted value
      )
    );
    // 7 $0 bench players (indices 2-8) - inside the outlier's initial
    // +-7 window, but never count toward the nonzero sample.
    for (Integer i = 0; i < 7; i++) {
      players.add(
        new Player__c(
          MFL_Id__c = 'z' + i,
          MFL_Name__c = 'Zero AAV ' + i,
          Position__c = 'QB',
          MFL_AAV__c = 0
        )
      );
    }
    // 7 more real, low-value players (indices 9-15) - just outside the
    // initial +-7 window, only reachable once the window expands.
    List<Decimal> furtherRealValues = new List<Decimal>{ 2, 3, 4, 5, 6, 7, 8 };
    for (Integer i = 0; i < furtherRealValues.size(); i++) {
      players.add(
        new Player__c(
          MFL_Id__c = 'far' + i,
          MFL_Name__c = 'Real Neighbour Far ' + i,
          Position__c = 'QB',
          MFL_AAV__c = furtherRealValues[i],
          AAV_Min__c = furtherRealValues[i] - 1,
          AAV_Max__c = furtherRealValues[i] + 1
        )
      );
    }
    insert players; // confidenceAdjustedAuctionValues() keys its result by Id

    Map<Id, Decimal> adjustedValues = MFLManagePlayers.confidenceAdjustedAuctionValues(
      players
    );

    // Expanded window's nonzero values: 2,3,4,5,6,7,8,10,90 (9 values).
    // The outlier's own confidence clamps to 0, so it's excluded from the
    // CONFIDENT subset (real1's 10 and all 7 "far" values clear
    // CONFIDENT_NEIGHBOR_THRESHOLD, giving 8 - well past
    // MIN_CONFIDENT_NEIGHBOR_SAMPLE_SIZE) - median of that confident
    // subset (2,3,4,5,6,7,8,10) is 5.5, not 6 (the full window's median,
    // which would also count the outlier's own unreliable 90). The
    // outlier's own blend weight is 0, so its adjusted value lands
    // exactly on that confident-subset anchor.
    Assert.areEqual(5.5, adjustedValues.get(players[1].Id));
  }

  @IsTest
  static void confidenceAdjustedAuctionValues_ConfidentSubsetAvailable_PreferredOverFullWindow() {
    // Mirrors the real TE case this was built for: a window already has
    // enough total nonzero values (5, meeting MIN_NEIGHBORHOOD_SAMPLE_SIZE)
    // without needing to expand, but two of those five are themselves
    // wide-spread, zero-confidence prices - noise that shouldn't be
    // treated as equally representative as the other three, genuinely
    // confident ones. The confident subset (20/15/25, median 20) should
    // be preferred over the full window's median (15/20/25/90/100 -> 25).
    Player__c target = new Player__c(
      MFL_Id__c = 'tgt',
      MFL_Name__c = 'Target',
      Position__c = 'QB',
      MFL_AAV__c = 20,
      AAV_Min__c = 18,
      AAV_Max__c = 22
    );
    Player__c confidentPeer1 = new Player__c(
      MFL_Id__c = 'cp1',
      MFL_Name__c = 'Confident Peer 1',
      Position__c = 'QB',
      MFL_AAV__c = 15,
      AAV_Min__c = 13,
      AAV_Max__c = 17
    );
    Player__c confidentPeer2 = new Player__c(
      MFL_Id__c = 'cp2',
      MFL_Name__c = 'Confident Peer 2',
      Position__c = 'QB',
      MFL_AAV__c = 25,
      AAV_Min__c = 23,
      AAV_Max__c = 27
    );
    Player__c noisyPeer1 = new Player__c(
      MFL_Id__c = 'np1',
      MFL_Name__c = 'Noisy Peer 1',
      Position__c = 'QB',
      MFL_AAV__c = 100,
      AAV_Min__c = 0,
      AAV_Max__c = 300 // spread 300 / avg 100 = 3.0, past scale -> confidence 0
    );
    Player__c noisyPeer2 = new Player__c(
      MFL_Id__c = 'np2',
      MFL_Name__c = 'Noisy Peer 2',
      Position__c = 'QB',
      MFL_AAV__c = 90,
      AAV_Min__c = 0,
      AAV_Max__c = 270 // spread 270 / avg 90 = 3.0, past scale -> confidence 0
    );
    List<Player__c> positionGroup = new List<Player__c>{
      target,
      confidentPeer1,
      confidentPeer2,
      noisyPeer1,
      noisyPeer2
    };
    insert positionGroup; // confidenceAdjustedAuctionValues() keys its result by Id

    Map<Id, Decimal> adjustedValues = MFLManagePlayers.confidenceAdjustedAuctionValues(
      positionGroup
    );

    // noisyPeer1's own confidence clamps to 0, so its adjusted value is
    // entirely its anchor. The confident subset (target/confidentPeer1/
    // confidentPeer2 = 20/15/25, median 20) should win over the full
    // window's median (15/20/25/90/100 = 25).
    Assert.areEqual(
      20,
      adjustedValues.get(noisyPeer1.Id),
      'The confident subset (20/15/25 -> median 20) should be preferred over the full window (15/20/25/90/100 -> median 25)'
    );
  }

  @IsTest
  static void confidenceAdjustedAuctionValues_ZeroAAVBench_DoesNotDragDownRealPlayersMedian() {
    // A real position group is mostly bench/inactive players nobody has
    // ever bid on ($0 raw AAV). Including those $0s in the median anchor
    // would drag it down to ~$0 and over-shrink every real player toward
    // nothing - this reproduces that with 5 zero-AAV bench players
    // alongside 2 players with genuine AAV, and verifies the bench
    // players are pinned at exactly 0 (not pulled up) while the real
    // players are anchored against each other's median, not the bench.
    List<Player__c> benchPlayers = new List<Player__c>();
    for (Integer i = 1; i <= 5; i++) {
      benchPlayers.add(
        new Player__c(
          MFL_Id__c = 'b' + i,
          MFL_Name__c = 'Bench Player ' + i,
          Position__c = 'QB',
          MFL_AAV__c = 0
        )
      );
    }
    Player__c reliablePlayer = new Player__c(
      MFL_Id__c = 'rel',
      MFL_Name__c = 'Reliable Player',
      Position__c = 'QB',
      MFL_AAV__c = 40,
      AAV_Min__c = 30,
      AAV_Max__c = 50 // spread 20 / avg 40 = 0.5; confidence = 1 - 0.5/2 = 0.75
    );
    Player__c volatilePlayer = new Player__c(
      MFL_Id__c = 'vol',
      MFL_Name__c = 'Volatile Player',
      Position__c = 'QB',
      MFL_AAV__c = 60,
      AAV_Min__c = 0,
      AAV_Max__c = 180 // spread 180 / avg 60 = 3.0, past scale -> confidence 0
    );

    List<Player__c> positionGroup = new List<Player__c>(benchPlayers);
    positionGroup.add(reliablePlayer);
    positionGroup.add(volatilePlayer);
    insert positionGroup;

    Map<Id, Decimal> adjustedValues = MFLManagePlayers.confidenceAdjustedAuctionValues(
      positionGroup
    );

    for (Player__c benchPlayer : benchPlayers) {
      Assert.areEqual(
        0,
        adjustedValues.get(benchPlayer.Id),
        'A player with $0 raw AAV has no signal to correct and should stay at exactly 0, not be pulled up toward a median'
      );
    }
    // Median of the two real AAVs (40, 60) is 50 - not 0, despite 5 of
    // the 7 players in the group having $0 raw AAV (those never count
    // toward the median at all, regardless of window size).
    // reliablePlayer's 0.75 confidence squares to a 0.5625 blend weight:
    // 0.5625*40 + 0.4375*50 = 44.375. volatilePlayer's confidence clamps
    // to 0, so it lands exactly on the median.
    Assert.areEqual(44.375, adjustedValues.get(reliablePlayer.Id));
    Assert.areEqual(50, adjustedValues.get(volatilePlayer.Id));
  }

  @IsTest
  static void managePlayers_NewPlayer_ComputesTiers() {
    Test.setMock(HttpCalloutMock.class, new MFLCalloutMock());

    Test.startTest();
    MFLManagePlayers.managePlayers();
    Test.stopTest();

    Player__c player = [
      SELECT Tier_Rank__c, Tier_Auction__c
      FROM Player__c
      WHERE MFL_Id__c = '1000'
    ];
    Assert.areEqual(
      1,
      player.Tier_Rank__c,
      'managePlayers() should compute tiers as part of the sync, not just fields sourced directly from MFL'
    );
    Assert.areEqual(1, player.Tier_Auction__c);
  }
}
