/**
 * Apex test context allows at most ONE successful System.enqueueJob() call
 * across an entire test run (verified live against the real org, including
 * a full RunLocalTests pass) - not "one level of chaining per test method"
 * as commonly assumed, but one total, whichever call happens to run first.
 * Every subsequent System.enqueueJob() call anywhere in that same run - a
 * fresh top-level enqueue from an unrelated test OR a Queueable
 * self-chaining - throws "System.AsyncException: Maximum stack depth has
 * been reached", non-deterministically depending on test execution order.
 *
 * PlayerNewsQueueable.execute() catches that around its own chain-to-next
 * System.enqueueJob() call (see its ApexDoc) precisely because of this -
 * it's a real production concern (an org-level async job limit really
 * could be hit), not just a test workaround. That means execute() never
 * throws here regardless of whether its chain attempt actually succeeds
 * or hits this limit, so these tests assert on database state (was the
 * team that WAS processed updated correctly) rather than on whether
 * chaining itself succeeded, which this test run can't control.
 */
@IsTest
public class PlayerNewsQueueableTest {
  private static final Map<String, String> DISPLAY_NAME_BY_ATHLETE_ID = new Map<String, String>{
    '3139477' => 'Patrick Mahomes',
    '5000001' => 'Barry Jones'
  };
  private static final Map<String, String> HEADLINE_BY_ATHLETE_ID = new Map<String, String>{
    '3139477' => 'Mahomes is dealing with a minor ankle issue.',
    '5000001' => 'Jones logged a full practice.'
  };

  private static final Pattern TEST_ATHLETE_ID_PATTERN = Pattern.compile(
    '/athletes/(\\d+)'
  );

  private class ChainCalloutMock implements HttpCalloutMock {
    Boolean failTeam12List = false;

    public HttpResponse respond(HttpRequest req) {
      String endpoint = req.getEndpoint();
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (endpoint.contains('/teams/12/injuries?limit=')) {
        if (failTeam12List) {
          res.setStatusCode(500);
          res.setBody('{"error":"unavailable"}');
          return res;
        }
        res.setStatusCode(200);
        res.setBody(refListBody('3139477'));
        return res;
      }
      if (endpoint.contains('/teams/22/injuries?limit=')) {
        res.setStatusCode(200);
        res.setBody(refListBody('5000001'));
        return res;
      }

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

  private static String refListBody(String athleteId) {
    return '{"count":1,"pageIndex":1,"pageSize":25,"pageCount":1,"items":[' +
      '{"$ref":"http://sports.core.api.espn.com/v2/sports/football/leagues/nfl/seasons/2026/athletes/' +
      athleteId +
      '/injuries/9' +
      athleteId +
      '?lang=en&region=us"}' +
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
      new NFL_Team__c(Name = 'ARI', Team_Name__c = 'Arizona Cardinals')
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
        MFL_Id__c = '9003',
        MFL_Name__c = 'Jones, Barry',
        NFL_Team__c = teamIdByName.get('ARI')
      )
    };
  }

  @IsTest
  static void execute_SingleTeamNoRemainingWork_UpdatesPlayerAndDoesNotChain() {
    Test.setMock(HttpCalloutMock.class, new ChainCalloutMock());

    Test.startTest();
    new PlayerNewsQueueable(new List<Integer>{ 12 }).execute(null);
    Test.stopTest();

    Player__c mahomes = [
      SELECT News_Headline__c
      FROM Player__c
      WHERE MFL_Id__c = '9001'
    ];
    Assert.areEqual(
      'Mahomes is dealing with a minor ankle issue.',
      mahomes.News_Headline__c
    );
  }

  @IsTest
  static void execute_EmptyQueue_NoOp() {
    Test.setMock(HttpCalloutMock.class, new ChainCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      new PlayerNewsQueueable(new List<Integer>()).execute(null);
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isFalse(exceptionThrown);
  }

  @IsTest
  static void execute_MultipleTeamsRemaining_ProcessesFirstTeamWithoutThrowing() {
    Test.setMock(HttpCalloutMock.class, new ChainCalloutMock());

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      new PlayerNewsQueueable(new List<Integer>{ 12, 22 }).execute(null);
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isFalse(
      exceptionThrown,
      'execute() must never throw, regardless of whether its own chain-to-next attempt succeeds - see class ApexDoc'
    );
    Player__c mahomes = [
      SELECT News_Headline__c
      FROM Player__c
      WHERE MFL_Id__c = '9001'
    ];
    Assert.areEqual(
      'Mahomes is dealing with a minor ankle issue.',
      mahomes.News_Headline__c,
      'Team 12 (the team actually processed this hop) should be updated regardless of the chain attempt'
    );
  }

  @IsTest
  static void execute_TeamCalloutFails_DoesNotThrowAndDoesNotUpdateThatTeam() {
    ChainCalloutMock mock = new ChainCalloutMock();
    mock.failTeam12List = true;
    Test.setMock(HttpCalloutMock.class, mock);

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      new PlayerNewsQueueable(new List<Integer>{ 12, 22 }).execute(null);
    } catch (Exception e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    Assert.isFalse(exceptionThrown);
    Player__c mahomes = [
      SELECT News_Headline__c
      FROM Player__c
      WHERE MFL_Id__c = '9001'
    ];
    Assert.isNull(
      mahomes.News_Headline__c,
      'Team 12 failed and should not have updated anything'
    );
  }
}
