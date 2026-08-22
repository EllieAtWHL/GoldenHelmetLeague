public with sharing class MFLManagePlayers {
  @TestVisible
  private class PlayersResponse {
    @TestVisible
    Players players;
  }
  @TestVisible
  private class Players {
    @TestVisible
    List<Player> player;
  }
  @TestVisible
  private class Player {
    @TestVisible
    String id;
    @TestVisible
    String name;
    @TestVisible
    String team;
    @TestVisible
    String position;
    @TestVisible
    String status;
  }
  private class ADPResponse {
    ADP adp;
  }
  private class ADP {
    List<ADP_Player> player;
  }
  private class ADP_Player {
    String id;
    String rank;
    String averagePick;
  }
  private class AAVResponse {
    AAV aav;
  }
  private class AAV {
    List<AAV_Player> player;
  }
  private class AAV_Player {
    String id;
    String averageValue;
  }
  private class RankPlayersResponse {
    PlayerRanks player_ranks;
  }
  private class PlayerRanks {
    List<Rank_Player> player;
  }
  private class Rank_Player {
    String id;
    String rank;
  }

  @AuraEnabled
  public static void managePlayers() {
    Logger.setScenario('Managing NFL Players');
    List<Player> mflNFLPlayers = getPlayers();

    Map<String, Player__c> nflPlayers = getNFLPlayers();

    List<ADP_Player> playersADP = getADP();
    Map<String, ADP_Player> mapPlayersADP = new Map<String, ADP_Player>();
    if (!playersADP.isEmpty()) {
      for (ADP_Player adpPlayer : playersADP) {
        mapPlayersADP.put(adpPlayer.id, adpPlayer);
      }
    }

    List<Rank_Player> playerRankList = getRank();
    Map<String, Rank_Player> mapPlayersRank = new Map<String, Rank_Player>();
    for (Rank_Player playerRank : playerRankList) {
      mapPlayersRank.put(playerRank.id, playerRank);
    }

    List<AAV_Player> playersAAV = getAAV();
    Map<String, AAV_Player> mapPlayersAAV = new Map<String, AAV_Player>();
    for (AAV_Player aavPlayer : playersAAV) {
      mapPlayersAAV.put(aavPlayer.id, aavPlayer);
    }

    Map<String, NFL_Team__c> mapTeams = MFLManageByeWeeks.getNFLTeams();
    Set<String> positions = getPositions();
    List<Player__c> playersToUpsert = new List<Player__c>();

    Id freeAgentTeamId = freeAgentTeam();

    for (Player player : mflNFLPlayers) {
      if (
        nflPlayers != null &&
        nflPlayers.containsKey(player.id) &&
        positions.contains(player.position)
      ) {
        if (
          playerChanged(
            player,
            nflPlayers,
            mapPlayersADP,
            mapPlayersRank,
            mapPlayersAAV,
            mapTeams
          ) == true
        ) {
          Player__c updatedPlayer = createPlayer(
            player,
            nflPlayers,
            mapPlayersADP,
            mapPlayersRank,
            mapPlayersAAV,
            mapTeams,
            freeAgentTeamId
          );
          playersToUpsert.add(updatedPlayer);
        }
      } else if (positions.contains(player.position)) {
        Player__c newPlayer = createPlayer(
          player,
          nflPlayers,
          mapPlayersADP,
          mapPlayersRank,
          mapPlayersAAV,
          mapTeams,
          freeAgentTeamId
        );
        playersToUpsert.add(newPlayer);
      }
    }
    upsert playersToUpsert;

    deletePlayersNoLongerDraftable(mflNFLPlayers, nflPlayers, positions);
  }

  /**
   * Removes Player__c records that can no longer legitimately be drafted:
   * either MFL no longer returns the player at all (retired, removed,
   * etc.), or MFL now reports them under a position outside this league's
   * Position__c picklist (MFL's players export includes every NFL player,
   * including e.g. individual defensive positions like LB/CB that this
   * league doesn't track). Both cases mean the sync's main loop would
   * silently skip the player forever, leaving a stale record behind.
   *
   * Never deletes a player who's already been drafted (Team_Owner__c
   * populated) - Pick__c.Player__c is a Master-Detail relationship, so
   * deleting a drafted player would cascade-delete their pick.
   */
  @TestVisible
  private static void deletePlayersNoLongerDraftable(
    List<Player> mflNFLPlayers,
    Map<String, Player__c> nflPlayers,
    Set<String> positions
  ) {
    Map<String, String> mflPlayerPositions = new Map<String, String>();
    for (Player player : mflNFLPlayers) {
      mflPlayerPositions.put(player.id, player.position);
    }

    List<Player__c> playersToDelete = new List<Player__c>();
    for (Player__c existingPlayer : nflPlayers.values()) {
      if (existingPlayer.Team_Owner__c != null) {
        continue;
      }

      Boolean stillInMFL = mflPlayerPositions.containsKey(
        existingPlayer.MFL_Id__c
      );
      Boolean positionStillTracked =
        stillInMFL &&
        positions.contains(mflPlayerPositions.get(existingPlayer.MFL_Id__c));

      if (!positionStillTracked) {
        playersToDelete.add(existingPlayer);
      }
    }

    if (playersToDelete.isEmpty()) {
      return;
    }

    try {
      delete playersToDelete;
    } catch (Exception e) {
      throw AuraExceptionHelper.logAndBuild(
        'Error deleting players no longer draftable',
        e
      );
    }
  }

  private static Player__c createPlayer(
    Player player,
    Map<String, Player__c> nflPlayers,
    Map<String, ADP_Player> mapPlayersADP,
    Map<String, Rank_Player> mapPlayersRank,
    Map<String, AAV_Player> mapPlayersAAV,
    Map<String, NFL_Team__c> mapTeams,
    Id freeAgentTeamId
  ) {
    Decimal adpRank;
    Decimal adpAverage;
    Decimal rank;
    Id teamID;
    Id playerId;
    if (mapPlayersADP.containsKey(player.id)) {
      adpRank = Decimal.valueOf(mapPlayersADP.get(player.id).rank);
      adpAverage = Decimal.valueOf(mapPlayersADP.get(player.id).averagePick);
    } else {
      adpRank = 9999;
    }
    if (mapPlayersRank.containsKey(player.id)) {
      rank = Decimal.valueOf(mapPlayersRank.get(player.id).rank);
    } else {
      rank = 9999;
    }
    Decimal rawAAV = getRawAAV(player.id, mapPlayersAAV);
    if (mapTeams.containsKey(player.team)) {
      teamId = mapTeams.get(player.team).Id;
    } else {
      teamId = freeAgentTeamId;
    }
    if (nflPlayers.containsKey(player.id)) {
      playerId = nflPlayers.get(player.id).Id;
    }
    Player__c newPlayer = new Player__c(
      Id = playerId,
      MFL_Id__c = player.id,
      MFL_Name__c = player.name,
      Position__c = player.position,
      MFL_Status__c = player.status,
      ADP_Rank__c = adpRank,
      ADP_Average__c = adpAverage,
      Experts_Rank__c = rank,
      MFL_AAV__c = rawAAV,
      NFL_Team__c = teamId
    );

    return newPlayer;
  }

  /**
   * MFL's raw Average Auction Value, unweighted for this league. It's
   * expressed as a normalized share of a notional $1000 per-team auction
   * budget, e.g. 82 means "typically ~8.2% of one team's budget". Defaults
   * to 0 when MFL doesn't return a value for this player, rather than
   * null. Player__c.Predicted_Auction_Cost__c is a formula field that
   * scales this to this league's actual per-team budget
   * (Draft_Settings__c.Auction_Budget__c) live, so Apex only needs to
   * keep this raw value in sync - the adjusted figure recalculates
   * automatically, even if the league's budget changes later.
   */
  private static Decimal getRawAAV(
    String playerId,
    Map<String, AAV_Player> mapPlayersAAV
  ) {
    if (
      !mapPlayersAAV.containsKey(playerId) ||
      mapPlayersAAV.get(playerId).averageValue == null
    ) {
      return 0;
    }
    return Decimal.valueOf(mapPlayersAAV.get(playerId).averageValue);
  }

  private static Boolean playerChanged(
    Player player,
    Map<String, Player__c> nflPlayers,
    Map<String, ADP_Player> mapPlayersADP,
    Map<String, Rank_Player> mapPlayersRank,
    Map<String, AAV_Player> mapPlayersAAV,
    Map<String, NFL_Team__c> mapTeams
  ) {
    //Checks ADP fields
    if (mapPlayersADP.containsKey(player.id)) {
      Decimal retrievedADPRank = Decimal.valueOf(
        mapPlayersADP.get(player.id).rank
      );
      Decimal retrievedADPAverage = Decimal.valueOf(
        mapPlayersADP.get(player.id).averagePick
      );
      Decimal storedADPRank = nflPlayers.get(player.id).ADP_Rank__c;
      Decimal storedADPAverage = nflPlayers.get(player.id).ADP_Average__c;

      if (
        retrievedADPAverage != storedADPAverage ||
        retrievedADPRank != storedADPRank
      ) {
        return true;
      }
    }
    //Checks raw AAV
    Decimal retrievedAAV = getRawAAV(player.id, mapPlayersAAV);
    if (retrievedAAV != nflPlayers.get(player.id).MFL_AAV__c) {
      return true;
    }
    //Checks Rank field
    if (mapPlayersRank.containsKey(player.id)) {
      Decimal retrievedRank = Decimal.valueOf(
        mapPlayersRank.get(player.id).rank
      );
      Decimal storedRank = nflPlayers.get(player.id).Experts_Rank__c;

      if (retrievedRank != storedRank) {
        return true;
      }
    }
    //Checks team
    String retrievedTeam = player.team;
    String storedTeam = nflPlayers.get(player.id).NFL_Team__r.Name;
    if (retrievedTeam != storedTeam) {
      return true;
    }
    //Checks position
    if (player.position != nflPlayers.get(player.id).Position__c) {
      return true;
    }
    return false;
  }
  @TestVisible
  private static List<Player> getPlayers() {
    MFL__c mfl = MFL__c.getInstance();

    String url = mfl.Instance_URL__c;
    url += '/' + mfl.Year__c;
    url += '/export?TYPE=players&L=' + mfl.League_Id__c;
    url += '&APIKEY=' + mfl.API_Key__c;
    url += '&DETAILS=&SINCE=&PLAYERS=&JSON=1';

    HttpResponse calloutResponse = new HttpResponse();
    try {
      calloutResponse = MFLRetrieveData.mflGetCallout(url);
    } catch (Exception e) {
      Logger.exception('Error getting players from MFL', e);
      Logger.saveLog();
      throw e;
    }

    PlayersResponse playerResponse = (PlayersResponse) JSON.deserialize(
      calloutResponse.getBody(),
      PlayersResponse.class
    );

    return playerResponse.players.player;
  }

  private static Map<String, Player__c> getNFLPlayers() {
    List<Player__c> players = [
      SELECT
        Id,
        MFL_Id__c,
        MFL_Name__c,
        NFL_Team__c,
        NFL_Team__r.Name,
        Position__c,
        MFL_Status__c,
        ADP_Average__c,
        ADP_Rank__c,
        Experts_Rank__c,
        MFL_AAV__c,
        Team_Owner__c
      FROM Player__c
      WITH USER_MODE
      ORDER BY ADP_Rank__c
    ];

    Map<String, Player__c> mapPlayers = new Map<String, Player__c>();

    for (Player__c player : players) {
      mapPlayers.put(player.MFL_Id__c, player);
    }

    return mapPlayers;
  }

  private static Set<String> getPositions() {
    Set<String> positions = new Set<String>();

    Schema.DescribeFieldResult positionField = Player__c.Position__c.getDescribe();
    List<Schema.PicklistEntry> positionValues = positionField.getPicklistValues();
    for (Schema.PicklistEntry value : positionValues) {
      positions.add(value.getLabel());
    }

    return positions;
  }

  private static List<ADP_Player> getADP() {
    MFL__c mfl = MFL__c.getInstance();

    String url = mfl.Generic_URL__c;
    url += '/' + mfl.Year__c;
    url += '/export?TYPE=adp&PERIOD=AUG1&FCOUNT=12&IS_PPR=1&IS_KEEPER=N&IS_MOCK=0&CUTOFF=10&DETAILS=&JSON=1';

    HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);

    ADPResponse adpResponse = (ADPResponse) JSON.deserialize(
      calloutResponse.getBody(),
      ADPResponse.class
    );

    if (adpResponse.adp.player == null) {
      return new List<ADP_Player>();
    }
    return adpResponse.adp.player;
  }

  private static List<AAV_Player> getAAV() {
    MFL__c mfl = MFL__c.getInstance();

    String url = mfl.Generic_URL__c;
    url += '/' + mfl.Year__c;
    url += '/export?TYPE=aav&PERIOD=RECENT&IS_PPR=1&IS_KEEPER=N&JSON=1';

    HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);

    AAVResponse aavResponse = (AAVResponse) JSON.deserialize(
      calloutResponse.getBody(),
      AAVResponse.class
    );

    if (aavResponse.aav.player == null) {
      return new List<AAV_Player>();
    }
    return aavResponse.aav.player;
  }

  private static List<Rank_Player> getRank() {
    MFL__c mfl = MFL__c.getInstance();

    String url = mfl.Generic_URL__c;
    url += '/' + mfl.Year__c;
    url += '/export?TYPE=playerRanks&POS=&JSON=1';

    HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);

    RankPlayersResponse rankResponse = (RankPlayersResponse) JSON.deserialize(
      calloutResponse.getBody(),
      RankPlayersResponse.class
    );

    return rankResponse.player_ranks.player;
  }

  private static Id freeAgentTeam() {
    List<NFL_Team__c> fa = [
      SELECT Id
      FROM NFL_Team__c
      WHERE Name = 'FA'
      LIMIT 1
    ];
    if (fa.isEmpty()) {
      NFL_Team__c faTeam = new NFL_Team__c(
        Name = 'FA',
        Team_Name__c = 'Free Agent'
      );
      insert faTeam;
      return faTeam.Id;
    } else {
      return fa[0].Id;
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Player__c> searchPlayers(String searchTerm) {
    Draft_Settings__c draftSettings = LeagueSetup.getDraftSettings();
    String orderField = (draftSettings.Ranking_Option__c == 'Fantasy Sharks')
      ? 'Experts_Rank__c'
      : 'ADP_Rank__c';
    String query;
    if (searchTerm == null || searchTerm.length() < 2) {
      query =
        'SELECT Id, MFL_Name__c, Photo_URL_Formula__c, Position__c, Team__c, MFL_Status__c FROM Player__c WHERE Team_Owner__c = NULL WITH USER_MODE ORDER BY ' +
        orderField +
        ' LIMIT 8';
      return Database.query(query);
    } else {
      String safeSearchTerm = String.escapeSingleQuotes('*' + searchTerm + '*');
      query =
        'FIND \'' +
        safeSearchTerm +
        '\' IN ALL FIELDS RETURNING Player__c ' +
        '(Id, MFL_Name__c, Photo_URL_Formula__c, Position__c, Team__c, MFL_Status__c ' +
        'WHERE Team_Owner__c = NULL ORDER BY ' +
        orderField +
        ' LIMIT 8)';
      List<List<SObject>> soslResult = Search.query(query);
      List<Player__c> playerList = ((List<Player__c>) soslResult[0]);
      return playerList;
    }
  }
}
