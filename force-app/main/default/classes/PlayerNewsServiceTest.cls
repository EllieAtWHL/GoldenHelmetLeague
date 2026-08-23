@IsTest
public class PlayerNewsServiceTest {
  private static final String MFL_INJURIES_BODY =
    '{"injuries":{"injury":[' +
    '{"id":"9001","status":"Questionable"},' +
    '{"id":"9002","status":"Out"}' +
    ']}}';

  private static final Map<String, String> DISPLAY_NAME_BY_ATHLETE_ID = new Map<String, String>{
    '3139477' => 'Patrick Mahomes',
    '4000001' => 'John Smith',
    '5000001' => 'B. Jones',
    '6001' => 'B. Jones'
  };
  private static final Map<String, String> HEADLINE_BY_ATHLETE_ID = new Map<String, String>{
    '3139477' => 'Mahomes is dealing with a minor ankle issue.',
    '4000001' => 'Smith practiced fully on Wednesday.',
    '5000001' => 'Jones logged a full practice.',
    '6001' => 'Jones logged a full practice.'
  };

  private static final Pattern TEST_ATHLETE_ID_PATTERN = Pattern.compile(
    '/athletes/(\\d+)'
  );

  private class PlayerNewsCalloutMock implements HttpCalloutMock {
    Boolean failTeam6List = false;

    public HttpResponse respond(HttpRequest req) {
      String endpoint = req.getEndpoint();
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (endpoint.contains('TYPE=injuries')) {
        res.setStatusCode(200);
        res.setBody(MFL_INJURIES_BODY);
        return res;
      }

      if (endpoint.contains('/teams/6/injuries?limit=')) {
        if (failTeam6List) {
          res.setStatusCode(500);
          res.setBody('{"error":"unavailable"}');
          return res;
        }
        // Two players share "Jones, B*" on the DAL roster - this entry
        // must be treated as ambiguous and skipped, not guessed at.
        res.setStatusCode(200);
        res.setBody(refListBody(new List<String>{ '6001' }));
        return res;
      }
      if (endpoint.contains('/teams/12/injuries?limit=')) {
        res.setStatusCode(200);
        res.setBody(refListBody(new List<String>{ '3139477', '4000001' }));
        return res;
      }
      if (endpoint.contains('/teams/22/injuries?limit=')) {
        // Only one "Jones" on this roster, so the last-name + first-initial
        // fallback should resolve unambiguously.
        res.setStatusCode(200);
        res.setBody(refListBody(new List<String>{ '5000001' }));
        return res;
      }

      // Injury detail dereference (the $ref URL itself, athlete id embedded).
      if (endpoint.contains('/injuries/')) {
        String athleteId = extractAthleteId(endpoint);
        res.setStatusCode(200);
        res.setBody(
          '{"status":"Questionable","shortComment":"' +
            HEADLINE_BY_ATHLETE_ID.get(athleteId) +
            '"}'
        );
        return res;
      }

      // Athlete profile dereference (cold-path identity resolution).
      if (endpoint.contains('/athletes/')) {
        String athleteId = extractAthleteId(endpoint);
        res.setStatusCode(200);
        res.setBody(
          '{"displayName":"' + DISPLAY_NAME_BY_ATHLETE_ID.get(athleteId) + '"}'
        );
        return res;
      }

      res.setStatusCode(200);
      res.setBody('{}');
      return res;
    }
  }

  private static String extractAthleteId(String endpoint) {
    Matcher matcher = TEST_ATHLETE_ID_PATTERN.matcher(endpoint);
    return matcher.find() ? matcher.group(1) : null;
  }

  private static String refListBody(List<String> athleteIds) {
    List<String> items = new List<String>();
    for (String athleteId : athleteIds) {
      items.add(
        '{"$ref":"http://sports.core.api.espn.com/v2/sports/football/leagues/nfl/seasons/2026/athletes/' +
          athleteId +
          '/injuries/9' +
          athleteId +
          '?lang=en&region=us"}'
      );
    }
    return '{"count":' +
      athleteIds.size() +
      ',"pageIndex":1,"pageSize":25,"pageCount":1,"items":[' +
      String.join(items, ',') +
      ']}';
  }

  @TestSetup
  static void makeData() {
    MFL__c mfl = new MFL__c();
    mfl.Generic_URL__c = 'https://api.example.com';
    mfl.Year__c = '2026';
    insert mfl;

    List<NFL_Team__c> teams = new List<NFL_Team__c>{
      new NFL_Team__c(Name = 'KCC', Team_Name__c = 'Kansas City Chiefs'),
      new NFL_Team__c(Name = 'ARI', Team_Name__c = 'Arizona Cardinals'),
      new NFL_Team__c(Name = 'DAL', Team_Name__c = 'Dallas Cowboys'),
      new NFL_Team__c(Name = 'FA', Team_Name__c = 'Free Agent')
    };
    insert teams;
    Map<String, Id> teamIdByName = new Map<String, Id>();
    for (NFL_Team__c team : teams) {
      teamIdByName.put(team.Name, team.Id);
    }

    insert new List<Player__c>{
      new Player__c(
        MFL_Id__c = '9001',
        MFL_Name__c = 'Mahomes, Patrick',
        NFL_Team__c = teamIdByName.get('KCC')
      ),
      new Player__c(
        MFL_Id__c = '9002',
        MFL_Name__c = 'Smith Jr., John',
        NFL_Team__c = teamIdByName.get('KCC')
      ),
      new Player__c(
        MFL_Id__c = '9003',
        MFL_Name__c = 'Jones, Barry',
        NFL_Team__c = teamIdByName.get('ARI')
      ),
      new Player__c(
        MFL_Id__c = '9004',
        MFL_Name__c = 'Jones, Barry',
        NFL_Team__c = teamIdByName.get('DAL')
      ),
      new Player__c(
        MFL_Id__c = '9005',
        MFL_Name__c = 'Jones, Benjamin',
        NFL_Team__c = teamIdByName.get('DAL')
      ),
      new Player__c(
        MFL_Id__c = '9006',
        MFL_Name__c = 'Stale Injury Player',
        NFL_Team__c = teamIdByName.get('ARI'),
        Injury_Status__c = 'Questionable'
      ),
      new Player__c(
        MFL_Id__c = '9007',
        MFL_Name__c = 'Free Agent Player',
        NFL_Team__c = teamIdByName.get('FA')
      )
    };
  }

  @IsTest
  static void refreshAllPlayerNews_SyncsMflAndAttemptsToEnqueueEspnChain() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    // Test.stopTest() is safe here even though this fixture has 3 ESPN
    // teams (so the enqueued PlayerNewsQueueable will itself try to
    // chain): both the initial enqueue in refreshAllPlayerNews() and the
    // chain's own re-enqueue in PlayerNewsQueueable.execute() catch and
    // log any System.enqueueJob() failure rather than letting it
    // propagate - see both classes. That also covers a real platform
    // constraint, not just a test-context one: verified live that Apex
    // test context allows at most one successful System.enqueueJob() call
    // across an entire test run, so a second attempt (this fixture's
    // chain hop) throwing here is expected and must not fail this test.
    Test.startTest();
    PlayerNewsService.refreshAllPlayerNews();
    Test.stopTest();

    Player__c mahomes = [
      SELECT Injury_Status__c
      FROM Player__c
      WHERE MFL_Id__c = '9001'
    ];
    Assert.areEqual('Questionable', mahomes.Injury_Status__c);

    Player__c staleInjuryPlayer = [
      SELECT Injury_Status__c
      FROM Player__c
      WHERE MFL_Id__c = '9006'
    ];
    Assert.isNull(
      staleInjuryPlayer.Injury_Status__c,
      'A player missing from MFL\'s injuries feed should have a stale designation cleared'
    );
  }

  @IsTest
  static void refreshEspnNewsForTeam_MatchesPlayerByExactNormalizedName_UpdatesNews() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    Test.startTest();
    PlayerNewsService.refreshEspnNewsForTeam(12);
    Test.stopTest();

    Player__c mahomes = [
      SELECT News_Headline__c, ESPN_Athlete_Id__c, News_Last_Updated__c
      FROM Player__c
      WHERE MFL_Id__c = '9001'
    ];
    Assert.areEqual(
      'Mahomes is dealing with a minor ankle issue.',
      mahomes.News_Headline__c
    );
    Assert.areEqual('3139477', mahomes.ESPN_Athlete_Id__c);
    Assert.isNotNull(mahomes.News_Last_Updated__c);
  }

  @IsTest
  static void refreshEspnNewsForTeam_SuffixAndSourceFormatDifferences_StillMatch() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    Test.startTest();
    PlayerNewsService.refreshEspnNewsForTeam(12);
    Test.stopTest();

    // MFL_Name__c "Smith Jr., John" vs ESPN displayName "John Smith" -
    // suffix stripped and comma-vs-space formats reconciled.
    Player__c smith = [
      SELECT News_Headline__c, ESPN_Athlete_Id__c
      FROM Player__c
      WHERE MFL_Id__c = '9002'
    ];
    Assert.areEqual(
      'Smith practiced fully on Wednesday.',
      smith.News_Headline__c
    );
    Assert.areEqual('4000001', smith.ESPN_Athlete_Id__c);
  }

  @IsTest
  static void refreshEspnNewsForTeam_UnambiguousInitialFallback_Matches() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    Test.startTest();
    PlayerNewsService.refreshEspnNewsForTeam(22);
    Test.stopTest();

    Player__c barryOnAri = [
      SELECT News_Headline__c
      FROM Player__c
      WHERE MFL_Id__c = '9003'
    ];
    Assert.areEqual(
      'Jones logged a full practice.',
      barryOnAri.News_Headline__c
    );
  }

  @IsTest
  static void refreshEspnNewsForTeam_AmbiguousLastNameFirstInitialMatch_SkipsWithoutThrowing() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    Test.startTest();
    PlayerNewsService.refreshEspnNewsForTeam(6);
    Test.stopTest();

    List<Player__c> dallasJoneses = [
      SELECT News_Headline__c
      FROM Player__c
      WHERE MFL_Id__c IN ('9004', '9005')
    ];
    for (Player__c player : dallasJoneses) {
      Assert.isNull(
        player.News_Headline__c,
        'An ambiguous match must not update either candidate'
      );
    }
  }

  @IsTest
  static void refreshEspnNewsForTeam_ListCalloutFails_ThrowsToCaller() {
    PlayerNewsCalloutMock mock = new PlayerNewsCalloutMock();
    mock.failTeam6List = true;
    Test.setMock(HttpCalloutMock.class, mock);

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      PlayerNewsService.refreshEspnNewsForTeam(6);
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isTrue(
      exceptionThrown,
      'A failed team-list callout should propagate to the caller (PlayerNewsQueueable), which is responsible for logging and continuing the chain'
    );
  }

  @IsTest
  static void refreshEspnNewsForTeam_CachedEspnAthleteId_MatchesEvenWhenNameNoLongerMatches() {
    // Simulates a player whose ESPN_Athlete_Id__c was already cached by an
    // earlier refresh, but whose name has since drifted out of sync (a
    // typo fix, a legal name change, etc.) - inserted directly with the id
    // pre-set, rather than caching it via a first callout and then
    // updating the name, because a DML statement followed by a second
    // callout in the same test method hits Apex's "uncommitted work
    // pending" restriction and Test.startTest() can only be called once
    // per test to work around it.
    Id kccTeamId = [SELECT Id FROM NFL_Team__c WHERE Name = 'KCC'].Id;
    insert new Player__c(
      MFL_Id__c = '9008',
      MFL_Name__c = 'Totally Different Name',
      NFL_Team__c = kccTeamId,
      ESPN_Athlete_Id__c = '3139477'
    );
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    Test.startTest();
    PlayerNewsService.refreshEspnNewsForTeam(12);
    Test.stopTest();

    Player__c player = [
      SELECT News_Headline__c
      FROM Player__c
      WHERE MFL_Id__c = '9008'
    ];
    Assert.areEqual(
      'Mahomes is dealing with a minor ankle issue.',
      player.News_Headline__c,
      'A cached ESPN_Athlete_Id__c should still match even if the name no longer would'
    );
  }

  @IsTest
  static void refreshEspnNewsForTeam_NoTeamMapping_NoOp() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());

    // 9999 isn't in ESPN_TEAM_ID_BY_MFL_TEAM_NAME's values - should just
    // return without attempting a callout or throwing.
    Test.startTest();
    PlayerNewsService.refreshEspnNewsForTeam(9999);
    Test.stopTest();
  }

  @IsTest
  static void refreshNewsForPlayer_NoEspnTeamMapping_DoesNotThrow() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());
    Id freeAgentPlayerId = [
      SELECT Id
      FROM Player__c
      WHERE MFL_Id__c = '9007'
    ]
    .Id;

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      PlayerNewsService.refreshNewsForPlayer(freeAgentPlayerId);
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isFalse(
      exceptionThrown,
      'A player with no ESPN team mapping (e.g. a free agent) must not throw'
    );
  }

  @IsTest
  static void refreshNewsForPlayer_CalloutFails_DoesNotThrow() {
    PlayerNewsCalloutMock mock = new PlayerNewsCalloutMock();
    mock.failTeam6List = true;
    Test.setMock(HttpCalloutMock.class, mock);
    Id dallasPlayerId = [
      SELECT Id
      FROM Player__c
      WHERE MFL_Id__c = '9004'
    ]
    .Id;

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      PlayerNewsService.refreshNewsForPlayer(dallasPlayerId);
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isFalse(
      exceptionThrown,
      'refreshNewsForPlayer must never throw a client-facing error'
    );
  }

  @IsTest
  static void refreshNewsForPlayer_Success_UpdatesHeadlineAndTimestamp() {
    Test.setMock(HttpCalloutMock.class, new PlayerNewsCalloutMock());
    Id mahomesId = [
      SELECT Id
      FROM Player__c
      WHERE MFL_Id__c = '9001'
    ]
    .Id;

    Test.startTest();
    PlayerNewsService.refreshNewsForPlayer(mahomesId);
    Test.stopTest();

    Player__c mahomes = [
      SELECT News_Headline__c, ESPN_Athlete_Id__c, News_Last_Updated__c
      FROM Player__c
      WHERE Id = :mahomesId
    ];
    Assert.areEqual(
      'Mahomes is dealing with a minor ankle issue.',
      mahomes.News_Headline__c
    );
    Assert.areEqual('3139477', mahomes.ESPN_Athlete_Id__c);
    Assert.isNotNull(mahomes.News_Last_Updated__c);
  }
}
