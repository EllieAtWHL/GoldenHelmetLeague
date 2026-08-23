/**
 * Backs the "My Draft Board" LWC (GHL-25) - a personal, live-updating view
 * of undrafted players and the user's own drafted roster, distinct from
 * the shared commissioner draft board on the Experience Cloud site.
 */
public with sharing class ManageMyDraftBoard {
  @AuraEnabled(cacheable=true)
  public static List<Player__c> getAllPlayers() {
    Logger.setScenario('Retrieving All Players for My Draft Board');
    try {
      return [
        SELECT
          Id,
          MFL_Name__c,
          Photo_URL_Formula__c,
          Position__c,
          Team__c,
          MFL_Status__c,
          ADP_Rank__c,
          Experts_Rank__c,
          Predicted_Auction_Cost__c,
          Tier_Rank__c,
          Tier_Auction__c,
          My_notes__c,
          Team_Owner__c,
          Injury_Status__c,
          News_Headline__c,
          News_Last_Updated__c,
          (SELECT Auction_Cost__c, Round__c, Round_Pick_Number__c FROM Picks__r)
        FROM Player__c
        WITH USER_MODE
        ORDER BY Position__c, Tier_Rank__c NULLS LAST, ADP_Rank__c NULLS LAST
      ];
    } catch (Exception e) {
      throw AuraExceptionHelper.logAndBuild('Error retrieving players', e);
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Player__c> getMyDraftedPlayers() {
    Logger.setScenario('Retrieving My Drafted Players for My Draft Board');
    try {
      return [
        SELECT
          Id,
          MFL_Name__c,
          Photo_URL_Formula__c,
          Position__c,
          Team__c,
          MFL_Status__c,
          My_notes__c,
          Team_Owner__c,
          Injury_Status__c,
          News_Headline__c,
          News_Last_Updated__c,
          (SELECT Auction_Cost__c, Round__c, Round_Pick_Number__c FROM Picks__r)
        FROM Player__c
        WHERE Team_Owner__r.Is_My_Team__c = TRUE
        WITH USER_MODE
        ORDER BY Position__c, MFL_Name__c
      ];
    } catch (Exception e) {
      throw AuraExceptionHelper.logAndBuild(
        'Error retrieving your drafted players',
        e
      );
    }
  }

  @AuraEnabled
  public static void updatePlayerNotes(Id playerId, String notes) {
    Logger.setScenario('Updating Player Notes');
    try {
      update new Player__c(Id = playerId, My_notes__c = notes);
      Logger.saveLog();
    } catch (Exception e) {
      throw AuraExceptionHelper.logAndBuild('Error updating player notes', e);
    }
  }
}
