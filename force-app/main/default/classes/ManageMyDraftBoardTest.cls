@isTest
public class ManageMyDraftBoardTest {
  // WITH USER_MODE throws when the running user lacks object/field access
  // to Player__c - Player__c access in this org is granted only via the
  // Commissioner permission set (see permissionsets/Commissioner), never
  // by profile, so a bare user on a minimal-access profile with no
  // permission set assigned has none.
  private static User createRestrictedUser() {
    Profile minimumAccess = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    User restrictedUser = new User(
      FirstName = 'Restricted',
      LastName = 'TestUser',
      Alias = 'rtestu',
      Email = 'restricted.testuser@ghl.test.invalid',
      Username = 'restricted.testuser@ghl.test.invalid.' +
        Crypto.getRandomInteger(),
      ProfileId = minimumAccess.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert restrictedUser;
    return restrictedUser;
  }

  @isTest
  static void getAllPlayers_ReturnsBothDraftedAndUndraftedPlayers() {
    Team_Owner__c team = TestDataFactory.createFranchises(1)[0];
    insert team;

    List<Player__c> players = TestDataFactory.createPlayers(2);
    players[0].Team_Owner__c = team.Id;
    players[0].Injury_Status__c = 'Questionable';
    players[0].News_Headline__c = 'Limited in practice on Wednesday.';
    players[0].News_Last_Updated__c = DateTime.now();
    insert players;

    Pick__c pick = TestDataFactory.createPicks(players[0].Id, team.Id, 1)[0];
    pick.Auction_Cost__c = 45;
    insert pick;

    Test.startTest();
    List<Player__c> result = ManageMyDraftBoard.getAllPlayers();
    Test.stopTest();

    Assert.areEqual(2, result.size());
    for (Player__c player : result) {
      if (player.Id == players[0].Id) {
        Assert.areEqual(team.Id, player.Team_Owner__c);
        Assert.areEqual(1, player.Picks__r.size());
        Assert.areEqual(45, player.Picks__r[0].Auction_Cost__c);
        Assert.areEqual('Questionable', player.Injury_Status__c);
        Assert.areEqual(
          'Limited in practice on Wednesday.',
          player.News_Headline__c
        );
        Assert.isNotNull(player.News_Last_Updated__c);
      } else {
        Assert.areEqual(null, player.Team_Owner__c);
      }
    }
  }

  @isTest
  static void getMyDraftedPlayers_ReturnsOnlyPlayersOnTheTeamMarkedAsMyTeam() {
    List<Team_Owner__c> teams = TestDataFactory.createFranchises(2);
    teams[0].Is_My_Team__c = true;
    insert teams;

    List<Player__c> players = TestDataFactory.createPlayers(2);
    players[0].Team_Owner__c = teams[0].Id;
    players[0].Injury_Status__c = 'Out';
    players[1].Team_Owner__c = teams[1].Id;
    insert players;

    Test.startTest();
    List<Player__c> result = ManageMyDraftBoard.getMyDraftedPlayers();
    Test.stopTest();

    Assert.areEqual(1, result.size());
    Assert.areEqual(players[0].Id, result[0].Id);
    Assert.areEqual('Out', result[0].Injury_Status__c);
  }

  @isTest
  static void getMyDraftedPlayers_NoTeamMarkedYet_ReturnsEmptyList() {
    Team_Owner__c team = TestDataFactory.createFranchises(1)[0];
    insert team;

    Player__c player = TestDataFactory.createPlayers(1)[0];
    player.Team_Owner__c = team.Id;
    insert player;

    Test.startTest();
    List<Player__c> result = ManageMyDraftBoard.getMyDraftedPlayers();
    Test.stopTest();

    Assert.areEqual(0, result.size());
  }

  @isTest
  static void updatePlayerNotes_UpdatesTheNotesField() {
    Player__c player = TestDataFactory.createPlayers(1)[0];
    insert player;

    Test.startTest();
    ManageMyDraftBoard.updatePlayerNotes(
      player.Id,
      'Watch out for injury risk'
    );
    Test.stopTest();

    Player__c updatedPlayer = [
      SELECT My_notes__c
      FROM Player__c
      WHERE Id = :player.Id
    ];
    Assert.areEqual('Watch out for injury risk', updatedPlayer.My_notes__c);
  }

  @isTest
  static void getAllPlayers_UserLacksFieldAccess_ThrowsAuraHandledException() {
    User restrictedUser = createRestrictedUser();

    Boolean exceptionThrown = false;
    Test.startTest();
    System.runAs(restrictedUser) {
      try {
        ManageMyDraftBoard.getAllPlayers();
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A user with no Player__c access should get an AuraHandledException, not a raw QueryException'
    );
  }

  @isTest
  static void getMyDraftedPlayers_UserLacksFieldAccess_ThrowsAuraHandledException() {
    User restrictedUser = createRestrictedUser();

    Boolean exceptionThrown = false;
    Test.startTest();
    System.runAs(restrictedUser) {
      try {
        ManageMyDraftBoard.getMyDraftedPlayers();
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A user with no Player__c access should get an AuraHandledException, not a raw QueryException'
    );
  }

  @isTest
  static void updatePlayerNotes_Exception() {
    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      ManageMyDraftBoard.updatePlayerNotes(null, 'Some notes');
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.areEqual(
      true,
      exceptionThrown,
      'An exception was not thrown as expected'
    );
  }
}
