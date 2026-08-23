/**
 * Surfaces injury/suspension/news status on Player__c for MyDraftBoard
 * (GHL-30), so a manager can see a player is compromised before bidding on
 * them. Two combined, free data sources:
 *
 * - MFL's TYPE=injuries export -> Injury_Status__c. Global, ungated export
 *   (same URL shape as TYPE=adp/aav/playerRanks - see
 *   MFLManagePlayers.getADP()) covering every NFL player, matched onto
 *   Player__c via MFL_Id__c. This league's single source of truth for
 *   Injury_Status__c - a player who drops out of this feed has that field
 *   explicitly cleared on the next refresh (see applyMflInjuries()).
 *
 * - ESPN's sports.core.api.espn.com -> News_Headline__c, ESPN_Athlete_Id__c,
 *   News_Last_Updated__c. NOT site.api.espn.com, which was the original
 *   choice here and looked simpler (one inlined GET per team) - confirmed
 *   live against this org's real Salesforce IP that Akamai's edge WAF
 *   403s every single call to that host (log a09J9000000GSF4IAO, 32/32
 *   teams denied), and a User-Agent header fix did not resolve it. Core.api
 *   IS reachable (confirmed 200 live), but every useful endpoint on it
 *   returns a paginated list of {"$ref": "..."} links rather than inline
 *   data - resolving one entry's status/comment needs a second GET on that
 *   $ref, and resolving the athlete's NAME needs a third GET (the injury
 *   detail's own "athlete" field is itself a $ref, not inlined). A full
 *   32-team refresh can therefore need hundreds of callouts, blowing past
 *   Apex's 100-per-transaction limit in one synchronous run - hence
 *   PlayerNewsQueueable, which chains one NFL team through per hop.
 *
 * The athlete id IS parseable straight from a $ref URL's text
 * (/athletes/{id}/) with no callout - see extractAthleteIdFromRef().
 *
 * refreshAllPlayerNews() (the "Refresh News" button) runs the MFL sync
 * synchronously - fast, one callout, Injury_Status__c is correct the
 * moment the button click returns - then kicks off the ESPN Queueable
 * chain and returns; it does not wait for ESPN. refreshNewsForPlayer()
 * (fired from draftCommisioner.js on nomination) hands off to a
 * @future(callout=true) method instead of a Queueable, since resolving one
 * player doesn't need chaining (bounded at ~1 team's worth of work) but IS
 * too slow (up to ~25 sequential callouts on a cold match) to risk running
 * inline on the synchronous Aura request the LWC already treats as
 * fire-and-forget.
 *
 * Both paths share refreshEspnNewsForTeam(Integer espnTeamId) for the
 * actual per-team fetch/match/dereference work, so that logic exists in
 * exactly one place.
 */
public with sharing class PlayerNewsService {
  @TestVisible
  private class MFLInjuriesResponse {
    @TestVisible
    MFLInjuries injuries;
  }
  @TestVisible
  private class MFLInjuries {
    @TestVisible
    List<MFLInjury> injury;
  }
  @TestVisible
  private class MFLInjury {
    @TestVisible
    String id;
    @TestVisible
    String status;
  }

  @TestVisible
  private class ESPNInjuryDetail {
    @TestVisible
    String status;
    @TestVisible
    String shortComment;
  }

  @TestVisible
  private class ESPNAthleteProfile {
    @TestVisible
    String displayName;
  }

  @TestVisible
  private class EspnRefEntry {
    @TestVisible
    String athleteId;
    @TestVisible
    String injuryRef;
  }

  /**
   * Tracks the best Player__c match found so far for a normalized name key
   * within one team's candidate list - null means two different players
   * on the same team produced the same key (e.g. shared last name and
   * first initial), so the key is ambiguous and must never be trusted.
   */
  private class NameIndex {
    Map<String, Player__c> byEspnAthleteId = new Map<String, Player__c>();
    Map<String, Player__c> byFullName = new Map<String, Player__c>();
    Map<String, Player__c> byLastNameFirstInitial = new Map<String, Player__c>();
  }

  private static final String ESPN_CORE_BASE_URL = 'https://sports.core.api.espn.com/v2/sports/football/leagues/nfl';
  private static final Pattern ATHLETE_ID_IN_REF_PATTERN = Pattern.compile(
    '/athletes/(\\d+)/'
  );

  @TestVisible
  private static final Map<String, Integer> ESPN_TEAM_ID_BY_MFL_TEAM_NAME = new Map<String, Integer>{
    'ARI' => 22,
    'ATL' => 1,
    'BAL' => 33,
    'BUF' => 2,
    'CAR' => 29,
    'CHI' => 3,
    'CIN' => 4,
    'CLE' => 5,
    'DAL' => 6,
    'DEN' => 7,
    'DET' => 8,
    'GBP' => 9,
    'HOU' => 34,
    'IND' => 11,
    'JAC' => 30,
    'KCC' => 12,
    'LAC' => 24,
    'LAR' => 14,
    'LVR' => 13,
    'MIA' => 15,
    'MIN' => 16,
    'NEP' => 17,
    'NOS' => 18,
    'NYG' => 19,
    'NYJ' => 20,
    'PHI' => 21,
    'PIT' => 23,
    'SEA' => 26,
    'SFO' => 25,
    'TBB' => 27,
    'TEN' => 10,
    'WAS' => 28
  };

  /**
   * Bulk pre-draft refresh: the "Refresh News" button in myDraftBoard. Runs
   * the MFL sync synchronously, then kicks off a PlayerNewsQueueable chain
   * for ESPN and returns immediately - it does not wait for ESPN to finish.
   */
  @AuraEnabled
  public static void refreshAllPlayerNews() {
    Logger.setScenario('Refreshing Player News');

    List<Player__c> allPlayers;
    try {
      allPlayers = [
        SELECT
          Id,
          MFL_Id__c,
          MFL_Name__c,
          NFL_Team__r.Name,
          Injury_Status__c,
          ESPN_Athlete_Id__c
        FROM Player__c
        WITH USER_MODE
      ];
    } catch (Exception e) {
      throw AuraExceptionHelper.logAndBuild(
        'Error retrieving players for news refresh',
        e
      );
    }

    Map<String, Player__c> playersByMflId = new Map<String, Player__c>();
    Set<Integer> espnTeamIds = new Set<Integer>();
    for (Player__c player : allPlayers) {
      if (String.isNotBlank(player.MFL_Id__c)) {
        playersByMflId.put(player.MFL_Id__c, player);
      }
      String teamName = player.NFL_Team__r?.Name;
      if (
        teamName != null && ESPN_TEAM_ID_BY_MFL_TEAM_NAME.containsKey(teamName)
      ) {
        espnTeamIds.add(ESPN_TEAM_ID_BY_MFL_TEAM_NAME.get(teamName));
      }
    }

    Map<Id, Player__c> playersToUpdate = new Map<Id, Player__c>();
    try {
      applyMflInjuries(allPlayers, playersByMflId, playersToUpdate);
      if (!playersToUpdate.isEmpty()) {
        update playersToUpdate.values();
      }
      Logger.saveLog();
    } catch (Exception e) {
      throw AuraExceptionHelper.logAndBuild(
        'Error refreshing MFL injury statuses',
        e
      );
    }

    if (!espnTeamIds.isEmpty()) {
      // The MFL half above has already succeeded and committed - a
      // failure only kicking off the ESPN chain (e.g. a platform-level
      // async job limit) shouldn't turn into a client-facing error for a
      // refresh that mostly worked.
      try {
        System.enqueueJob(
          new PlayerNewsQueueable(new List<Integer>(espnTeamIds))
        );
      } catch (Exception e) {
        Logger.warn('Failed to enqueue ESPN news refresh: ' + e.getMessage());
        Logger.saveLog();
      }
    }
  }

  /**
   * Nomination-triggered refresh for one player, fired from
   * draftCommisioner.js without blocking the nomination itself. Hands off
   * to a @future method rather than doing the work inline - see class
   * ApexDoc. Never surfaces a client-facing error either way - a failed or
   * unavailable news callout must not break the live draft (GHL-30 AC).
   */
  @AuraEnabled
  public static void refreshNewsForPlayer(Id playerId) {
    refreshNewsForPlayerAsync(playerId);
  }

  @future(callout=true)
  private static void refreshNewsForPlayerAsync(Id playerId) {
    Logger.setScenario('Refreshing News for Nominated Player');
    try {
      List<Player__c> matches = [
        SELECT Id, NFL_Team__r.Name
        FROM Player__c
        WHERE Id = :playerId
        WITH USER_MODE
        LIMIT 1
      ];
      if (matches.isEmpty()) {
        Logger.warn('refreshNewsForPlayer: player not found - ' + playerId);
      } else {
        String teamName = matches[0].NFL_Team__r?.Name;
        Integer espnTeamId = teamName != null
          ? ESPN_TEAM_ID_BY_MFL_TEAM_NAME.get(teamName)
          : null;
        if (espnTeamId == null) {
          Logger.warn(
            'refreshNewsForPlayer: no ESPN team mapping for ' + teamName
          );
        } else {
          refreshEspnNewsForTeam(espnTeamId);
        }
      }
      Logger.saveLog();
    } catch (Exception e) {
      Logger.warn(
        'refreshNewsForPlayer failed for ' + playerId + ': ' + e.getMessage()
      );
      Logger.saveLog();
    }

    publishNewsUpdatedEvent(playerId);
  }

  /**
   * The actual per-team ESPN fetch/match/dereference work, shared by
   * PlayerNewsQueueable (bulk, one team per hop) and
   * refreshNewsForPlayerAsync (single player). Public - called cross-class
   * by PlayerNewsQueueable. Every per-item failure is caught individually
   * so one bad entry never stops the rest of this team's list from being
   * processed; a failure fetching the team's list itself propagates to the
   * caller, which is responsible for logging it and not aborting whatever
   * else it was doing (the Queueable chain, or the future's own catch).
   */
  public static void refreshEspnNewsForTeam(Integer espnTeamId) {
    String mflTeamName = mflTeamNameForEspnId(espnTeamId);
    if (mflTeamName == null) {
      return;
    }

    List<Player__c> teamPlayers = [
      SELECT Id, MFL_Name__c, ESPN_Athlete_Id__c
      FROM Player__c
      WHERE NFL_Team__r.Name = :mflTeamName
      WITH USER_MODE
    ];
    if (teamPlayers.isEmpty()) {
      return;
    }

    List<EspnRefEntry> refEntries = fetchTeamInjuryRefs(espnTeamId);
    NameIndex index = buildNameIndex(teamPlayers);
    Map<Id, Player__c> playersToUpdate = new Map<Id, Player__c>();
    DateTime refreshedAt = DateTime.now();

    for (EspnRefEntry entry : refEntries) {
      try {
        processRefEntry(entry, index, playersToUpdate, refreshedAt, espnTeamId);
      } catch (Exception e) {
        Logger.warn(
          'Error processing ESPN news entry for ESPN team ' +
            espnTeamId +
            ': ' +
            e.getMessage()
        );
      }
    }

    if (!playersToUpdate.isEmpty()) {
      update playersToUpdate.values();
    }
    Logger.saveLog();

    publishNewsUpdatedEvent(null);
  }

  private static void processRefEntry(
    EspnRefEntry entry,
    NameIndex index,
    Map<Id, Player__c> playersToUpdate,
    DateTime refreshedAt,
    Integer espnTeamId
  ) {
    Player__c match = (entry.athleteId != null &&
      index.byEspnAthleteId.containsKey(entry.athleteId))
      ? index.byEspnAthleteId.get(entry.athleteId)
      : null;

    if (match == null) {
      // Cold path: no cached id yet, so resolve identity by name.
      String displayName = fetchAthleteDisplayName(entry.athleteId);
      match = matchAthlete(index, entry.athleteId, displayName);
      if (match == null) {
        Logger.warn(
          'Unable to match ESPN news entry to a player: athlete ' +
            entry.athleteId +
            ' (ESPN team ' +
            espnTeamId +
            ')'
        );
        return;
      }
      getOrCreateUpdate(playersToUpdate, match.Id)
        .ESPN_Athlete_Id__c = entry.athleteId;
    }

    ESPNInjuryDetail detail = fetchInjuryDetail(entry.injuryRef);
    if (detail == null) {
      return;
    }
    Player__c playerUpdate = getOrCreateUpdate(playersToUpdate, match.Id);
    playerUpdate.News_Headline__c = truncateTo255(detail.shortComment);
    playerUpdate.News_Last_Updated__c = refreshedAt;
  }

  private static String mflTeamNameForEspnId(Integer espnTeamId) {
    for (String mflTeamName : ESPN_TEAM_ID_BY_MFL_TEAM_NAME.keySet()) {
      if (ESPN_TEAM_ID_BY_MFL_TEAM_NAME.get(mflTeamName) == espnTeamId) {
        return mflTeamName;
      }
    }
    return null;
  }

  @TestVisible
  private static List<EspnRefEntry> fetchTeamInjuryRefs(Integer espnTeamId) {
    HttpResponse res = ESPNRetrieveData.espnGetCallout(
      ESPN_CORE_BASE_URL + '/teams/' + espnTeamId + '/injuries?limit=25'
    );
    List<EspnRefEntry> entries = new List<EspnRefEntry>();
    Object parsed = JSON.deserializeUntyped(res.getBody());
    if (!(parsed instanceof Map<String, Object>)) {
      return entries;
    }
    Object itemsObj = ((Map<String, Object>) parsed).get('items');
    if (!(itemsObj instanceof List<Object>)) {
      return entries;
    }
    for (Object itemObj : (List<Object>) itemsObj) {
      if (!(itemObj instanceof Map<String, Object>)) {
        continue;
      }
      Object refObj = ((Map<String, Object>) itemObj).get('$ref');
      if (!(refObj instanceof String)) {
        continue;
      }
      String ref = (String) refObj;
      EspnRefEntry entry = new EspnRefEntry();
      entry.injuryRef = ref;
      entry.athleteId = extractAthleteIdFromRef(ref);
      entries.add(entry);
    }
    return entries;
  }

  @TestVisible
  private static String extractAthleteIdFromRef(String ref) {
    if (ref == null) {
      return null;
    }
    Matcher matcher = ATHLETE_ID_IN_REF_PATTERN.matcher(ref);
    return matcher.find() ? matcher.group(1) : null;
  }

  private static String fetchAthleteDisplayName(String athleteId) {
    if (athleteId == null) {
      return null;
    }
    MFL__c mfl = MFL__c.getInstance();
    String url =
      ESPN_CORE_BASE_URL +
      '/seasons/' +
      mfl.Year__c +
      '/athletes/' +
      athleteId +
      '?lang=en&region=us';
    HttpResponse res = ESPNRetrieveData.espnGetCallout(url);
    ESPNAthleteProfile profile = (ESPNAthleteProfile) JSON.deserialize(
      res.getBody(),
      ESPNAthleteProfile.class
    );
    return profile?.displayName;
  }

  private static ESPNInjuryDetail fetchInjuryDetail(String injuryRef) {
    // ESPN's $ref URLs come back as plain http:// - normalize to https://
    // before calling out, since Salesforce callouts require it.
    String secureRef = injuryRef.replace('http://', 'https://');
    HttpResponse res = ESPNRetrieveData.espnGetCallout(secureRef);
    return (ESPNInjuryDetail) JSON.deserialize(
      res.getBody(),
      ESPNInjuryDetail.class
    );
  }

  private static void publishNewsUpdatedEvent(Id playerId) {
    Player_News_Updated__e event = new Player_News_Updated__e();
    event.Player_Id__c = playerId;
    EventBus.publish(event);
  }

  private static void applyMflInjuries(
    List<Player__c> allPlayers,
    Map<String, Player__c> playersByMflId,
    Map<Id, Player__c> playersToUpdate
  ) {
    MFL__c mfl = MFL__c.getInstance();
    String url =
      mfl.Generic_URL__c +
      '/' +
      mfl.Year__c +
      '/export?TYPE=injuries&JSON=1';
    HttpResponse res = MFLRetrieveData.mflGetCallout(url);
    MFLInjuriesResponse parsed = (MFLInjuriesResponse) JSON.deserialize(
      res.getBody(),
      MFLInjuriesResponse.class
    );
    if (parsed?.injuries?.injury == null) {
      return;
    }

    Set<String> mflIdsWithActiveDesignation = new Set<String>();
    for (MFLInjury injury : parsed.injuries.injury) {
      if (!playersByMflId.containsKey(injury.id)) {
        continue;
      }
      mflIdsWithActiveDesignation.add(injury.id);
      Player__c match = playersByMflId.get(injury.id);
      getOrCreateUpdate(playersToUpdate, match.Id)
        .Injury_Status__c = injury.status;
    }

    // A player who's dropped out of MFL's feed has recovered/been
    // reinstated - clear the stale designation rather than leaving a
    // misleading badge in place indefinitely.
    for (Player__c player : allPlayers) {
      if (
        String.isNotBlank(player.Injury_Status__c) &&
        !mflIdsWithActiveDesignation.contains(player.MFL_Id__c)
      ) {
        getOrCreateUpdate(playersToUpdate, player.Id).Injury_Status__c = null;
      }
    }
  }

  private static NameIndex buildNameIndex(List<Player__c> candidates) {
    NameIndex index = new NameIndex();
    for (Player__c player : candidates) {
      if (String.isNotBlank(player.ESPN_Athlete_Id__c)) {
        index.byEspnAthleteId.put(player.ESPN_Athlete_Id__c, player);
      }

      String fullKey = normalizeName(player.MFL_Name__c);
      if (fullKey == null) {
        continue;
      }
      putOrMarkAmbiguous(index.byFullName, fullKey, player);

      String initialKey = lastNameFirstInitialKey(fullKey);
      if (initialKey != null) {
        putOrMarkAmbiguous(index.byLastNameFirstInitial, initialKey, player);
      }
    }
    return index;
  }

  private static void putOrMarkAmbiguous(
    Map<String, Player__c> index,
    String key,
    Player__c player
  ) {
    if (!index.containsKey(key)) {
      index.put(key, player);
    } else if (index.get(key) != null && index.get(key).Id != player.Id) {
      index.put(key, null);
    }
  }

  private static Player__c matchAthlete(
    NameIndex index,
    String athleteId,
    String athleteDisplayName
  ) {
    if (athleteId != null && index.byEspnAthleteId.containsKey(athleteId)) {
      return index.byEspnAthleteId.get(athleteId);
    }

    String fullKey = normalizeName(athleteDisplayName);
    if (fullKey == null) {
      return null;
    }
    if (index.byFullName.containsKey(fullKey)) {
      return index.byFullName.get(fullKey);
    }

    String initialKey = lastNameFirstInitialKey(fullKey);
    if (
      initialKey != null && index.byLastNameFirstInitial.containsKey(initialKey)
    ) {
      return index.byLastNameFirstInitial.get(initialKey);
    }

    return null;
  }

  /**
   * Canonical "last,first" key for a name in either MFL's typical
   * "Last, First" export format or ESPN's "First Last" displayName, so
   * both sides compare equal regardless of source formatting. Suffixes
   * (Jr./Sr./II-V) and periods are stripped first so "D.J. Moore Jr." and
   * "DJ Moore" both key the same.
   */
  @TestVisible
  private static String normalizeName(String rawName) {
    if (String.isBlank(rawName)) {
      return null;
    }
    String name = rawName.toLowerCase().trim();
    name = name.replace('.', '');
    name = name.replaceAll('\\s+', ' ');
    // Handles "First Last Jr." (ESPN-style - suffix is the final token of
    // the whole string).
    name = name.replaceAll('\\s+(jr|sr|ii|iii|iv|v)$', '');

    String last;
    String first;
    if (name.contains(',')) {
      List<String> parts = name.split(',', 2);
      last = parts[0].trim();
      first = parts.size() > 1 ? parts[1].trim() : '';
    } else {
      List<String> tokens = name.split(' ');
      last = tokens[tokens.size() - 1];
      List<String> firstTokens = new List<String>();
      for (Integer i = 0; i < tokens.size() - 1; i++) {
        firstTokens.add(tokens[i]);
      }
      first = String.join(firstTokens, ' ');
    }
    // Handles "Last Jr., First" (MFL-style - suffix attaches to the
    // surname, before the comma). A no-op if the strip above already
    // handled it.
    last = last.replaceAll('\\s+(jr|sr|ii|iii|iv|v)$', '');

    return last + ',' + first;
  }

  private static String lastNameFirstInitialKey(String fullKey) {
    List<String> parts = fullKey.split(',');
    if (parts.size() != 2 || String.isBlank(parts[1])) {
      return null;
    }
    return parts[0] + ',' + parts[1].substring(0, 1);
  }

  private static String truncateTo255(String text) {
    if (text == null) {
      return null;
    }
    return text.length() > 255 ? text.substring(0, 255) : text;
  }

  private static Player__c getOrCreateUpdate(
    Map<Id, Player__c> playersToUpdate,
    Id playerId
  ) {
    if (!playersToUpdate.containsKey(playerId)) {
      playersToUpdate.put(playerId, new Player__c(Id = playerId));
    }
    return playersToUpdate.get(playerId);
  }
}
