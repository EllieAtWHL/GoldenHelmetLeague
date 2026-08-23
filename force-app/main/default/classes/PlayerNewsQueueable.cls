/**
 * Chains through the ESPN team-id queue built by
 * PlayerNewsService.refreshAllPlayerNews(), one NFL team per hop. Needed
 * because a full 32-team ESPN refresh can take hundreds of callouts
 * (sports.core.api.espn.com returns paginated {"$ref": "..."} links that
 * each need a follow-up GET - see PlayerNewsService's ApexDoc), well past
 * Apex's 100-callouts-per-transaction limit if attempted in one
 * synchronous run. Each hop gets its own fresh governor limits, so
 * processing exactly one team per execute() keeps every hop comfortably
 * within them (see PlayerNewsService.refreshEspnNewsForTeam's own
 * ApexDoc for that budget).
 *
 * A failure processing one team (caught in execute(), not inside
 * refreshEspnNewsForTeam) is logged and does not stop the chain - the
 * next team is enqueued regardless, mirroring this ticket's "one bad
 * team never aborts the batch" principle from the original synchronous
 * design.
 */
public with sharing class PlayerNewsQueueable implements Queueable, Database.AllowsCallouts {
  private List<Integer> remainingEspnTeamIds;

  public PlayerNewsQueueable(List<Integer> remainingEspnTeamIds) {
    this.remainingEspnTeamIds = remainingEspnTeamIds;
  }

  public void execute(QueueableContext ctx) {
    if (remainingEspnTeamIds.isEmpty()) {
      return;
    }

    Integer espnTeamId = remainingEspnTeamIds.remove(0);
    try {
      PlayerNewsService.refreshEspnNewsForTeam(espnTeamId);
    } catch (Exception e) {
      Logger.warn(
        'ESPN news refresh failed for ESPN team ' +
          espnTeamId +
          ': ' +
          e.getMessage()
      );
      Logger.saveLog();
    }

    if (!remainingEspnTeamIds.isEmpty()) {
      try {
        System.enqueueJob(new PlayerNewsQueueable(remainingEspnTeamIds));
      } catch (Exception e) {
        Logger.warn(
          'Failed to chain to the next ESPN team - ' +
            remainingEspnTeamIds.size() +
            ' team(s) will not be refreshed this run: ' +
            e.getMessage()
        );
        Logger.saveLog();
      }
    }
  }
}
