@IsTest
public with sharing class ManageDraftTest {
  @TestSetup
  static void makeData() {
    Draft_Settings__c settings = new Draft_Settings__c();
    settings.Draft_Type__c = 'snake';
    settings.Number_of_Rounds__c = 10;
    insert settings;
  }

  @IsTest
  static void getDraft_NoPicksMade_IsSnake() {
    Test.startTest();
    ManageDraft.Draft draft = ManageDraft.getDraft();
    Test.stopTest();

    Assert.areEqual('snake', draft.draftType);
    Assert.areEqual(10, draft.numberOfRounds);
    Assert.areEqual(10, draft.rounds.size());
  }

  @IsTest
  static void getDraft_PicksMade_IsSnake() {
    TestDataFactory.createTestDraft();

    Test.startTest();
    ManageDraft.Draft draft = ManageDraft.getDraft();
    Test.stopTest();

    Assert.areEqual('snake', draft.draftType);
    Assert.areEqual(10, draft.numberOfRounds);
    Assert.areEqual(10, draft.rounds.size());
    //TODO: Assert actual picks
  }

  @IsTest
  static void getDraft_NoPicksMade_IsAuction() {
    Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
    settings.Draft_Type__c = 'auction';
    update settings;

    Test.startTest();
    ManageDraft.Draft draft = ManageDraft.getDraft();
    Test.stopTest();

    Assert.areEqual('auction', draft.draftType);
    Assert.areEqual(17, draft.numberOfRounds);
    Assert.areEqual(17, draft.rounds.size());
  }

  @IsTest
  static void getDraft_PicksMade_IsAuction() {
    Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
    settings.Draft_Type__c = 'auction';
    update settings;
    TestDataFactory.createTestDraft();

    Test.startTest();
    ManageDraft.Draft draft = ManageDraft.getDraft();
    Test.stopTest();

    Assert.areEqual('auction', draft.draftType);
    Assert.areEqual(17, draft.numberOfRounds);
    Assert.areEqual(17, draft.rounds.size());
    //TODO: add asserts
  }

  @IsTest
  static void getPicks_NoPicksFound() {
    Test.startTest();
    Map<Integer, Pick__c> picks = ManageDraft.getPicks();
    Test.stopTest();

    Assert.areEqual(0, picks.size());
  }

  @IsTest
  static void getPicks_PicksFound() {
    TestDataFactory.createTestDraft();

    Test.startTest();
    Map<Integer, Pick__c> picks = ManageDraft.getPicks();
    Test.stopTest();

    Assert.areEqual(5, picks.size());
    for (Integer i = 0; i < picks.size(); i++) {
      Integer pickNumber = Integer.valueOf(
        picks.get(i + 1).Overall_Pick_Number__c
      );
      Assert.areEqual(i + 1, pickNumber);
    }
  }

  @IsTest
  static void makePick_SnakePick() {
    Player__c player = TestDataFactory.createPlayers(1)[0];
    insert player;
    Team_Owner__c team = TestDataFactory.createFranchises(1)[0];
    insert team;

    Pick__c pickToMake = new Pick__c(
      Player__c = player.Id,
      Team_Owner__c = team.Id,
      Round_Pick_Number__c = 1,
      Overall_Pick_Number__c = 1,
      Round__c = 1
    );

    Test.startTest();
    ManageDraft.makePick(pickToMake, 'Test Player');
    Test.stopTest();

    Pick__c insertedPick = [
      SELECT Player__c, Team_Owner__c
      FROM Pick__c
      WHERE Overall_Pick_Number__c = 1
    ];
    Assert.areEqual(player.Id, insertedPick.Player__c);
    Player__c updatedPlayer = [
      SELECT Team_Owner__c
      FROM Player__c
      WHERE Id = :player.Id
    ];
    Assert.areEqual(team.Id, updatedPlayer.Team_Owner__c);
  }

  @IsTest
  static void makePick_AuctionPick() {
    Draft_Settings__c settings = Draft_Settings__c.getOrgDefaults();
    settings.Auction_Budget__c = 100;
    update settings;

    Player__c player = TestDataFactory.createPlayers(1)[0];
    insert player;
    Team_Owner__c team = TestDataFactory.createFranchises(1)[0];
    insert team;

    Pick__c pickToMake = new Pick__c(
      Player__c = player.Id,
      Team_Owner__c = team.Id,
      Round_Pick_Number__c = 1,
      Overall_Pick_Number__c = 1,
      Round__c = 1,
      Auction_Cost__c = 25
    );

    Test.startTest();
    ManageDraft.makePick(pickToMake, 'Test Player');
    Test.stopTest();

    Pick__c insertedPick = [
      SELECT Player__c, Auction_Cost__c
      FROM Pick__c
      WHERE Overall_Pick_Number__c = 1
    ];
    Assert.areEqual(player.Id, insertedPick.Player__c);
    Assert.areEqual(25, insertedPick.Auction_Cost__c);
  }

  @IsTest
  static void makePick_PlayerAlreadyPicked_ThrowsError() {
    Player__c player = TestDataFactory.createPlayers(1)[0];
    insert player;
    List<Team_Owner__c> teams = TestDataFactory.createFranchises(2);
    insert teams;

    Pick__c firstPick = new Pick__c(
      Player__c = player.Id,
      Team_Owner__c = teams[0].Id,
      Round_Pick_Number__c = 1,
      Overall_Pick_Number__c = 1,
      Round__c = 1
    );
    ManageDraft.makePick(firstPick, 'Test Player');

    Pick__c secondPick = new Pick__c(
      Player__c = player.Id,
      Team_Owner__c = teams[1].Id,
      Round_Pick_Number__c = 2,
      Overall_Pick_Number__c = 2,
      Round__c = 1
    );

    Test.startTest();
    try {
      ManageDraft.makePick(secondPick, 'Test Player');
      Assert.fail('Expected duplicate pick exception was not thrown');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('already been made'));
    }
    Test.stopTest();

    Integer picksForPlayer = [
      SELECT COUNT()
      FROM Pick__c
      WHERE Player__c = :player.Id
    ];
    Assert.areEqual(1, picksForPlayer);
  }

  @IsTest
  static void undoPick_Success() {
    //TODO: Test undoing a pick
  }

  @IsTest
  static void publishDraftUpdatedPlatformEvent_Success() {
    //TODO: Test publishing platform event for draftMessage
  }

  @IsTest
  static void publishDraftMessagePlatformEvent_Success() {
    //TODO: Test publishing platform event for draftMessage
  }

  @IsTest
  static void submitDraft_OK() {
    //TODO: Successful callout
  }

  @IsTest
  static void submitDraft_Fail() {
    //TODO: Failed callout
  }
}
