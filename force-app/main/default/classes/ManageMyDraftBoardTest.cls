@isTest
public class ManageMyDraftBoardTest {
  @isTest
  static void getAllPlayers_ReturnsBothDraftedAndUndraftedPlayers() {
    Team_Owner__c team = TestDataFactory.createFranchises(1)[0];
    insert team;

    List<Player__c> players = TestDataFactory.createPlayers(2);
    players[0].Team_Owner__c = team.Id;
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
    players[1].Team_Owner__c = teams[1].Id;
    insert players;

    Test.startTest();
    List<Player__c> result = ManageMyDraftBoard.getMyDraftedPlayers();
    Test.stopTest();

    Assert.areEqual(1, result.size());
    Assert.areEqual(players[0].Id, result[0].Id);
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
