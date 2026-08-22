/**
 * Syncs Player__c from MyFantasyLeague (MFL) and computes this league's
 * own view of player value on top of that synced data - positional
 * tiers and a confidence-adjusted predicted auction cost. See GHL-27 in
 * Jira for the full investigation behind the tiering/valuation
 * algorithm (why it exists, what real 2026 data cases it was tuned
 * against, and the approaches that were tried and rejected along the
 * way) - the ApexDoc on the constants and methods below covers the
 * same ground but the ticket has the narrative.
 *
 * Two entry points:
 * - managePlayers(): the full sync, wired to the "Sync Players" button
 *   in the manageRecords LWC (League Setup panel, org Home page). Pulls
 *   four separate exports from MFL (player roster, ADP, expert
 *   consensus rank, auction value), merges them onto Player__c, then
 *   recomputes tiers/predicted cost for the whole league.
 * - searchPlayers(): powers the live "who's available" search used
 *   during an actual draft pick (draftSelectPick LWC).
 *
 * At a glance, the tiering/valuation pipeline (computeTiers()) does
 * three things per position, in order:
 * 1. Tier_Rank__c - gap-detection on ADP_Rank__c/Experts_Rank__c
 *    (whichever this league's Ranking_Option__c prefers).
 * 2. A confidence-adjusted version of MFL_AAV__c (see
 *    confidenceAdjustedAuctionValues()) - shrinks a player's raw
 *    auction value toward what similarly-ranked players go for, in
 *    proportion to how wide (and therefore unreliable) MFL reports
 *    their own price spread to be. This same adjusted value drives both
 *    Tier_Auction__c (another gap-detection pass) and
 *    Predicted_Auction_Cost__c (scaled to this league's real budget
 *    pool via predictedAuctionCost()).
 */
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
    String minValue;
    String maxValue;
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

  /**
   * Full player sync: pulls this league's roster plus three generic MFL
   * exports (ADP, expert consensus rank, auction value), upserts
   * anything new or changed onto Player__c, removes players MFL no
   * longer tracks (see deletePlayersNoLongerDraftable()), then
   * recomputes this league's own tiers/predicted cost for every
   * position (see computeTiers()) so they reflect the freshly-synced
   * data. Safe to re-run at any time - createPlayer()/playerChanged()
   * only touch a record when something MFL reports has actually
   * changed, and computeTiers() only writes a player whose tier or
   * predicted cost actually moved.
   */
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

    computeTiers();
  }

  /**
   * Multiplier applied to the standard deviation of gaps between
   * consecutive REAL (non-sentinel) values (within one position, sorted
   * by value) to decide how big a gap has to be before it counts as a
   * tier break. Lower = more, smaller tiers; higher = fewer, bigger
   * tiers. Checked against real 2026 WR data: 1.0 was too sensitive for
   * auction value (nearly one tier per player among the top 8) and,
   * separately, still left every real-ranked WR crammed into a single
   * rank tier before the sentinel-exclusion fix in assignTiers() existed
   * to address that half of the problem; 1.5 produced sensible groupings
   * for both dimensions at once (top 8 WRs split into 3 tiers by rank, 3
   * by auction value) without needing separate constants per metric.
   * Like the other tunable constants here, still a starting point.
   */
  @TestVisible
  private static final Decimal GAP_THRESHOLD_MULTIPLIER = 1.5;

  /**
   * How much a wide MFL_AAV__c min/max spread discounts trust in
   * averageValue, expressed as the spread-to-average ratio at which
   * confidence bottoms out at 0. E.g. with a scale of 2, a player whose
   * (max - min) is 2x their average is fully distrusted; half that
   * spread is trusted about half as much. Checked against real 2026 QB
   * data: 3.0 wasn't aggressive enough to stop a hyped rookie's raw AAV
   * (nearly double the next-highest QB's, but with a huge min/max
   * spread) from still coming out on top; 2.0 correctly drops it (and a
   * second similarly-hyped rookie) out of the top tier without
   * overcorrecting real veteran starters the way 1.5 and below did. Like
   * GAP_THRESHOLD_MULTIPLIER, this is still a starting point - re-check
   * it as more of the season's real auction data comes in.
   */
  @TestVisible
  private static final Decimal SPREAD_CONFIDENCE_SCALE = 2.0;

  /**
   * Starting size (and expansion step - see localMedianForAnchor()) for
   * how many players on each side of a player's own rank position count
   * as their "neighbourhood" when computing the local median AAV anchor
   * (see confidenceAdjustedAuctionValues()) - e.g. 7 means starting with
   * a window of up to 15 players (7 before, 7 after, plus the player
   * themselves) centered on their own rank, widening by another 7 either
   * side at a time if that isn't enough real data (see
   * MIN_NEIGHBORHOOD_SAMPLE_SIZE). Checked against real 2026 RB data: a
   * hyped rookie ranked ~10th at the position but priced at 4x what the
   * consensus top-2 backs actually go for kept a $50+ predicted cost
   * under a position-wide median (dragged down by hundreds of bench
   * players), because a top-10 player being unusual relative to the
   * *whole* position isn't actually surprising. Anchoring against
   * players ranked near them instead catches that a price is out of
   * line with what similarly-ranked peers go for. Like the other
   * tunable constants here, still a starting point.
   */
  @TestVisible
  private static final Integer RANK_NEIGHBORHOOD_SIZE = 7;

  /**
   * Minimum count of nonzero raw AAVs a rank neighbourhood needs before
   * its median is trusted as an anchor (see localMedianForAnchor()) -
   * below this, the window keeps widening by RANK_NEIGHBORHOOD_SIZE
   * until it either finds enough or has expanded to cover the whole
   * position. Checked against a real deep-bench cluster where a
   * player's only two nonzero-priced neighbours both happened to be
   * known-hyped rookies - a median of just those two took their own
   * inflated prices at face value. Requiring more data points before
   * trusting the median (5 real prices found a $3ish anchor instead of
   * $19, dominated by neither outlier) is more robust than trying to
   * classify individual neighbours as trustworthy or not, which caused
   * its own bug: several genuinely low-value players (near-zero raw AAV,
   * no real rank) all happened to share the SAME low confidence as the
   * hyped rookies this was meant to catch, so they all got anchored to
   * the same distant "good player" fallback instead of a value
   * reflecting how little real interest they actually have.
   */
  @TestVisible
  private static final Integer MIN_NEIGHBORHOOD_SAMPLE_SIZE = 5;

  /**
   * Confidence (see auctionValueConfidence()) a neighbour needs to count
   * toward the CONFIDENT subset localMedianForAnchor() prefers when one
   * is available (see MIN_CONFIDENT_NEIGHBOR_SAMPLE_SIZE). Checked
   * against real TE data: MIN_NEIGHBORHOOD_SAMPLE_SIZE forced an elite
   * TE's window to reach past 4-5 genuinely comparable neighbours
   * (confidence 0.34-0.6) into the next three names down, who all
   * happened to be zero-confidence noise - dragging a legitimately
   * elite player's anchor down to reflect "TE market broadly" instead of
   * "what similarly-good TEs go for." 0.25 matches the floor already
   * used elsewhere in this class as "not obviously noise."
   */
  @TestVisible
  private static final Decimal CONFIDENT_NEIGHBOR_THRESHOLD = 0.25;

  /**
   * Minimum count of CONFIDENT (see CONFIDENT_NEIGHBOR_THRESHOLD)
   * neighbours localMedianForAnchor() needs before preferring their
   * median over the full window's. Below this, falls back to the full
   * window exactly as before - this is deliberately a PREFERENCE with a
   * fallback, not a hard requirement like the trustworthy-neighbour
   * filter this replaced (see git history for why that version broke:
   * it forced an unrelated global fallback whenever a whole
   * neighbourhood happened to share low confidence, even when those
   * players were just genuinely cheap, not noisy). A hyped-rookie
   * cluster like Mendoza/Ty Simpson never has 3 confident neighbours
   * nearby, so it keeps falling back to the full-window median exactly
   * as validated before; a thin-but-real position like TE usually does,
   * so it gets the cleaner anchor.
   */
  @TestVisible
  private static final Integer MIN_CONFIDENT_NEIGHBOR_SAMPLE_SIZE = 3;

  /**
   * How much Experts_Rank__c counts versus ADP_Rank__c when picking the
   * rank neighbourhood an auction value gets anchored against (see
   * expertWeightedRankValues() and confidenceAdjustedAuctionValues()) -
   * 1 would mean experts only, 0.5 an even split. This is deliberately
   * independent of Draft_Settings__c.Ranking_Option__c (which only
   * controls Tier_Rank__c/searchPlayers() - a league's own display
   * preference), because ADP is still crowd data and can carry some of
   * the same hype-driven noise auction value already needs correcting
   * for - e.g. a rookie's ADP_Rank__c can look reasonable while
   * Experts_Rank__c places them hundreds of spots worse. Leaning the
   * anchor toward the more curated source makes it more trustworthy
   * without discarding ADP entirely. Starting point, not a full
   * override - tune by eye like the other constants here.
   */
  @TestVisible
  private static final Decimal EXPERTS_RANK_WEIGHT = 0.65;

  /**
   * Buckets players into per-position tiers using gap-detection: within
   * each Position__c group, sort by the relevant value metric and start a
   * new tier wherever the gap to the next player is unusually large
   * relative to the other gaps in that group. Computed from data already
   * synced from MFL - Tier_Rank__c from the same rank field
   * searchPlayers() sorts by (Experts_Rank__c/ADP_Rank__c depending on
   * Draft_Settings__c.Ranking_Option__c), Tier_Auction__c from a
   * confidence-adjusted version of MFL_AAV__c (see
   * confidenceAdjustedAuctionValues()) - so no external data source or
   * player-matching is needed. Also recomputes Predicted_Auction_Cost__c
   * from that same confidence-adjusted value (see
   * predictedAuctionCost()), so the number shown for a player's expected
   * cost is consistent with the tier it puts them in.
   *
   * Runs over every Player__c, not just this sync cycle's changes,
   * because tiers are a property of the whole position group: one
   * player's tier can shift when a different player's rank changes.
   */
  @TestVisible
  private static void computeTiers() {
    Draft_Settings__c draftSettings = LeagueSetup.getDraftSettings();
    String rankField = (draftSettings.Ranking_Option__c == 'Fantasy Sharks')
      ? 'Experts_Rank__c'
      : 'ADP_Rank__c';
    Integer teamCount = [SELECT COUNT() FROM Team_Owner__c];

    List<Player__c> allPlayers = [
      SELECT
        Id,
        Position__c,
        Tier_Rank__c,
        Tier_Auction__c,
        Predicted_Auction_Cost__c,
        MFL_AAV__c,
        AAV_Min__c,
        AAV_Max__c,
        ADP_Rank__c,
        Experts_Rank__c
      FROM Player__c
    ];

    Map<String, List<Player__c>> playersByPosition = new Map<String, List<Player__c>>();
    for (Player__c player : allPlayers) {
      if (!playersByPosition.containsKey(player.Position__c)) {
        playersByPosition.put(player.Position__c, new List<Player__c>());
      }
      playersByPosition.get(player.Position__c).add(player);
    }

    List<Player__c> playersToUpdate = new List<Player__c>();
    for (List<Player__c> positionGroup : playersByPosition.values()) {
      Map<Id, Decimal> rankValues = metricValuesByField(
        positionGroup,
        rankField
      );
      positionGroup.sort(new ValueComparator(rankValues, false));
      Map<Id, Integer> rankTiers = assignTiers(positionGroup, rankValues, 9999);

      Map<Id, Decimal> auctionAnchorRankValues = expertWeightedRankValues(
        positionGroup
      );
      positionGroup.sort(new ValueComparator(auctionAnchorRankValues, false));
      Map<Id, Decimal> auctionValues = confidenceAdjustedAuctionValues(
        positionGroup
      );
      positionGroup.sort(new ValueComparator(auctionValues, true));
      Map<Id, Integer> auctionTiers = assignTiers(
        positionGroup,
        auctionValues,
        0
      );

      for (Player__c player : positionGroup) {
        Integer newRankTier = rankTiers.get(player.Id);
        Integer newAuctionTier = auctionTiers.get(player.Id);
        Decimal newPredictedAuctionCost = predictedAuctionCost(
          auctionValues.get(player.Id),
          draftSettings.Auction_Budget__c,
          teamCount
        );
        if (
          player.Tier_Rank__c != newRankTier ||
          player.Tier_Auction__c != newAuctionTier ||
          player.Predicted_Auction_Cost__c != newPredictedAuctionCost
        ) {
          playersToUpdate.add(
            new Player__c(
              Id = player.Id,
              Tier_Rank__c = newRankTier,
              Tier_Auction__c = newAuctionTier,
              Predicted_Auction_Cost__c = newPredictedAuctionCost
            )
          );
        }
      }
    }

    if (!playersToUpdate.isEmpty()) {
      update playersToUpdate;
    }
  }

  /**
   * Assigns a tier number (1 = best) to every player in sortedGroup,
   * which must already be sorted best-to-worst by metricValues. Starts a
   * new tier wherever the gap to the next player exceeds the average gap
   * between REAL (non-sentinel) values in this group by more than
   * GAP_THRESHOLD_MULTIPLIER standard deviations - i.e. wherever the
   * drop-off is unusually large compared to the normal step between
   * neighbouring players at this position.
   *
   * sentinelValue is the "no real data" marker for this metric - 9999
   * for rank fields (metricValue()'s default for a missing rank), 0 for
   * confidence-adjusted auction values (confidenceAdjustedAuctionValues()
   * pins players with no raw AAV to exactly 0). Most position groups are
   * mostly bench/replacement/unranked players sharing that one sentinel,
   * which otherwise wrecks the average-gap statistic in opposite
   * directions depending on the metric: for rank, the single huge jump
   * from the last real rank up to 9999 inflates the standard deviation
   * so much that no real gap ever looks large by comparison, dumping
   * almost the whole position into tier 1; for auction value, the sea of
   * $0 gaps between bench players shrinks the average gap toward zero,
   * making even small real gaps between stars look enormous, splitting
   * them into a tier apiece. Computing the threshold only from gaps
   * between consecutive real values sidesteps both - sentinel players
   * still get walked through and tiered (typically landing in one final
   * tier together, since the gaps between them are usually 0 and the
   * transition into the sentinel run is its own large, real gap), just
   * without corrupting the threshold used for everyone else.
   */
  @TestVisible
  private static Map<Id, Integer> assignTiers(
    List<Player__c> sortedGroup,
    Map<Id, Decimal> metricValues,
    Decimal sentinelValue
  ) {
    Map<Id, Integer> tiers = new Map<Id, Integer>();
    if (sortedGroup.isEmpty()) {
      return tiers;
    }

    List<Decimal> allGaps = new List<Decimal>();
    List<Decimal> realGaps = new List<Decimal>();
    Decimal previousValue = metricValues.get(sortedGroup[0].Id);
    Decimal previousRealValue = (previousValue == sentinelValue)
      ? null
      : previousValue;
    for (Integer i = 1; i < sortedGroup.size(); i++) {
      Decimal currentValue = metricValues.get(sortedGroup[i].Id);
      allGaps.add(Math.abs(currentValue - previousValue));

      if (currentValue != sentinelValue) {
        if (previousRealValue != null) {
          realGaps.add(Math.abs(currentValue - previousRealValue));
        }
        previousRealValue = currentValue;
      }
      previousValue = currentValue;
    }

    Decimal averageGap = average(realGaps);
    Decimal gapStandardDeviation = standardDeviation(realGaps, averageGap);
    Decimal tierBreakThreshold =
      averageGap + (GAP_THRESHOLD_MULTIPLIER * gapStandardDeviation);

    Integer currentTier = 1;
    tiers.put(sortedGroup[0].Id, currentTier);
    for (Integer i = 1; i < sortedGroup.size(); i++) {
      if (allGaps[i - 1] > tierBreakThreshold) {
        currentTier++;
      }
      tiers.put(sortedGroup[i].Id, currentTier);
    }

    return tiers;
  }

  private static Map<Id, Decimal> metricValuesByField(
    List<Player__c> players,
    String fieldName
  ) {
    Map<Id, Decimal> values = new Map<Id, Decimal>();
    for (Player__c player : players) {
      values.put(player.Id, metricValue(player, fieldName));
    }
    return values;
  }

  /**
   * A blended rank - EXPERTS_RANK_WEIGHT toward Experts_Rank__c, the
   * rest toward ADP_Rank__c - used only to order positionGroup for
   * confidenceAdjustedAuctionValues()'s rank-neighbourhood anchor. Lower
   * is still better, same convention as either rank field alone.
   */
  @TestVisible
  private static Map<Id, Decimal> expertWeightedRankValues(
    List<Player__c> players
  ) {
    Map<Id, Decimal> values = new Map<Id, Decimal>();
    for (Player__c player : players) {
      Decimal adpRank = metricValue(player, 'ADP_Rank__c');
      Decimal expertsRank = metricValue(player, 'Experts_Rank__c');
      values.put(
        player.Id,
        (EXPERTS_RANK_WEIGHT * expertsRank) +
        ((1 - EXPERTS_RANK_WEIGHT) * adpRank)
      );
    }
    return values;
  }

  /**
   * MFL_AAV__c is a single average that can hide wildly disagreeing
   * prices behind it - e.g. an unproven rookie some drafters ignore and
   * others speculatively overpay for, versus an established player the
   * whole market broadly agrees on. Rather than trusting every average
   * equally (or discarding a wide-spread one outright), this shrinks
   * each player's raw AAV toward a median AAV, in proportion to how wide
   * their own MFL-reported min/max spread is relative to their average
   * (see auctionValueConfidence()). A tight spread barely moves; a wide
   * one gets pulled toward what's typical instead of standing on an
   * unreliable number alone.
   *
   * The median anchor is LOCAL to each player's own rank neighbourhood
   * (see RANK_NEIGHBORHOOD_SIZE and localMedianForAnchor()), not one
   * figure for the whole position - positionGroup must already be
   * sorted by expertWeightedRankValues() when this is called, since rank
   * neighbourhood is read directly from list position. A position-wide
   * median is dragged down by the many bench/replacement players every
   * position has, which wrongly treats a genuinely elite player's high
   * price as suspicious just for being unusual relative to the whole
   * position. Anchoring against players ranked near them instead catches
   * the actual problem case: a price many multiples of what
   * similarly-ranked players go for. The neighbourhood leans toward
   * Experts_Rank__c over ADP_Rank__c (see EXPERTS_RANK_WEIGHT) rather
   * than whichever field Draft_Settings__c.Ranking_Option__c currently
   * picks for Tier_Rank__c - ADP is still crowd data and can carry some
   * of the same noise this whole adjustment exists to correct for.
   *
   * The median anchor widens itself (see localMedianForAnchor() and
   * MIN_NEIGHBORHOOD_SAMPLE_SIZE) until it has enough real (nonzero) raw
   * AAVs to be a reasonably stable statistic - most position groups are
   * mostly bench/inactive players nobody has ever bid on, and a tiny
   * sample size a couple of noisy neighbours can dominate isn't a
   * trustworthy median regardless of how each neighbour is individually
   * classified. $0 raw AAVs never count toward it at all - that's not a
   * noisy signal to correct, it's an absence of one, so those players
   * are pinned at $0 directly rather than run through the shrinkage
   * formula at all.
   *
   * The blend weight is confidence SQUARED, not confidence itself.
   * Checked against a real hyped rookie whose raw AAV (~$82) was ~4x
   * even the best-ranked player at the same position: a merely-low
   * (~19%) linear confidence still let that extreme raw value dominate
   * the blend, because 19% of an extreme number is still a large
   * absolute amount - it landed above legitimately elite, established
   * players. Squaring confidence (~19% -> ~3.5%) suppresses that
   * contribution much harder specifically when confidence is already
   * low, while barely changing anything for players whose confidence is
   * already high.
   */
  @TestVisible
  private static Map<Id, Decimal> confidenceAdjustedAuctionValues(
    List<Player__c> positionGroup
  ) {
    List<Decimal> rawValuesByRank = new List<Decimal>();
    List<Decimal> confidenceByRank = new List<Decimal>();
    for (Player__c player : positionGroup) {
      Decimal rawValue = metricValue(player, 'MFL_AAV__c');
      rawValuesByRank.add(rawValue);
      confidenceByRank.add(auctionValueConfidence(player, rawValue));
    }

    Map<Id, Decimal> adjustedValues = new Map<Id, Decimal>();
    for (Integer i = 0; i < positionGroup.size(); i++) {
      Player__c player = positionGroup[i];
      Decimal rawValue = rawValuesByRank[i];
      if (rawValue == 0) {
        adjustedValues.put(player.Id, 0);
        continue;
      }
      Decimal localMedian = localMedianForAnchor(
        rawValuesByRank,
        confidenceByRank,
        i
      );
      Decimal confidence = confidenceByRank[i];
      Decimal blendWeight = confidence * confidence;
      adjustedValues.put(
        player.Id,
        (blendWeight * rawValue) + ((1 - blendWeight) * localMedian)
      );
    }
    return adjustedValues;
  }

  /**
   * Anchor for index in rawValuesByRank (a list of raw AAVs already
   * ordered best-to-worst by rank): finds a rank-neighbourhood window
   * exactly like before (widening by RANK_NEIGHBORHOOD_SIZE until
   * MIN_NEIGHBORHOOD_SAMPLE_SIZE nonzero values are found, or the window
   * covers the whole position), then prefers the median of just the
   * CONFIDENT nonzero values in that window (see
   * CONFIDENT_NEIGHBOR_THRESHOLD) if there are at least
   * MIN_CONFIDENT_NEIGHBOR_SAMPLE_SIZE of them - falling back to the
   * median of the full window otherwise. This is a preference layered on
   * top of the existing window, not a replacement for it: a thin
   * neighbourhood with 3+ genuinely confident prices nearby gets a
   * cleaner anchor that isn't diluted by noisier stragglers the window
   * had to reach for; a neighbourhood where confident data simply isn't
   * available (a hyped-rookie cluster surrounded by other noisy
   * deep-bench prices) falls straight back to the already-validated
   * full-window median, unchanged.
   */
  private static Decimal localMedianForAnchor(
    List<Decimal> rawValuesByRank,
    List<Decimal> confidenceByRank,
    Integer index
  ) {
    Integer windowSize = RANK_NEIGHBORHOOD_SIZE;
    Integer lastIndex = rawValuesByRank.size() - 1;
    List<Decimal> windowValues;
    List<Decimal> windowConfidences;
    Integer windowStart;
    Integer windowEnd;
    do {
      windowStart = Math.max(0, index - windowSize);
      windowEnd = Math.min(lastIndex, index + windowSize);
      windowValues = new List<Decimal>();
      windowConfidences = new List<Decimal>();
      for (Integer i = windowStart; i <= windowEnd; i++) {
        if (rawValuesByRank[i] > 0) {
          windowValues.add(rawValuesByRank[i]);
          windowConfidences.add(confidenceByRank[i]);
        }
      }
      windowSize += RANK_NEIGHBORHOOD_SIZE;
    } while (
      windowValues.size() < MIN_NEIGHBORHOOD_SAMPLE_SIZE &&
      (windowStart > 0 ||
      windowEnd < lastIndex)
    );

    List<Decimal> confidentValues = new List<Decimal>();
    for (Integer i = 0; i < windowValues.size(); i++) {
      if (windowConfidences[i] >= CONFIDENT_NEIGHBOR_THRESHOLD) {
        confidentValues.add(windowValues[i]);
      }
    }
    if (confidentValues.size() >= MIN_CONFIDENT_NEIGHBOR_SAMPLE_SIZE) {
      return median(confidentValues);
    }

    return median(windowValues);
  }

  /**
   * How much to trust a player's raw MFL_AAV__c, from 0 (fully
   * distrusted, use the group median instead) to 1 (fully trusted, use
   * as-is). Derived from AAV_Min__c/AAV_Max__c - the wider that spread is
   * relative to the average, the less confidence. A player synced before
   * these fields existed, or whose AAV hasn't changed since (so
   * createPlayer() had no reason to rewrite it), won't have spread data
   * yet; that's an absence of evidence, not evidence of unreliability, so
   * it defaults to full confidence rather than guessing.
   */
  @TestVisible
  private static Decimal auctionValueConfidence(
    Player__c player,
    Decimal averageValue
  ) {
    if (averageValue == 0) {
      return 0;
    }
    if (player.get('AAV_Min__c') == null || player.get('AAV_Max__c') == null) {
      return 1;
    }
    Decimal minValue = (Decimal) player.get('AAV_Min__c');
    Decimal maxValue = (Decimal) player.get('AAV_Max__c');
    Decimal spreadRatio = (maxValue - minValue) / averageValue;
    Decimal confidence = 1 - (spreadRatio / SPREAD_CONFIDENCE_SCALE);
    if (confidence < 0) {
      return 0;
    }
    return confidence > 1 ? 1 : confidence;
  }

  private static Decimal median(List<Decimal> values) {
    if (values.isEmpty()) {
      return 0;
    }
    List<Decimal> sortedValues = values.clone();
    sortedValues.sort();
    Integer size = sortedValues.size();
    if (Math.mod(size, 2) == 1) {
      return sortedValues[size / 2];
    }
    return (sortedValues[size / 2 - 1] + sortedValues[size / 2]) / 2;
  }

  /**
   * Predicted_Auction_Cost__c: a confidence-adjusted auction value scaled
   * to this league's actual budget. Used to be a live formula straight
   * off MFL_AAV__c (see git history), but the confidence adjustment
   * needs the whole position group, not just one record, so it can't be
   * a formula anymore - computeTiers() now writes this directly, same as
   * Tier_Auction__c. Rounded to the field's own scale (2) so re-saving an
   * unchanged value doesn't look like a change purely from
   * floating-point noise.
   *
   * MFL_AAV__c's $1000 isn't one team's budget - per MFL's own API docs,
   * "Average auction value is relative to an auction where a total of
   * $1000 is available across all franchises" - i.e. the whole league's
   * combined pool, not a per-team figure. A previous version of this
   * method (and its test) got this backwards and asserted team count
   * must NOT factor in, which is why predicted costs looked
   * unrealistically low - a $200/team, 12-team league's real combined
   * pool is $2400, not $200.
   */
  @TestVisible
  private static Decimal predictedAuctionCost(
    Decimal adjustedAuctionValue,
    Decimal auctionBudget,
    Integer teamCount
  ) {
    if (adjustedAuctionValue == null || auctionBudget == null) {
      return 0;
    }
    return (adjustedAuctionValue /
      1000 *
      (teamCount * auctionBudget))
      .setScale(2);
  }

  /**
   * Player__c.ADP_Rank__c, Experts_Rank__c and MFL_AAV__c are all
   * optional at the schema level, so a legacy or manually-created record
   * can have any of them null even though createPlayer() always
   * populates them for anything actually synced from MFL. Reads null the
   * same way createPlayer()/getRawAAV() already treat a player MFL
   * doesn't return a value for: worst-possible rank (9999) or
   * worst-possible AAV (0), so one incomplete record can't blow up gap
   * detection for its whole position group.
   */
  private static Decimal metricValue(SObject player, String fieldName) {
    Object rawValue = player.get(fieldName);
    if (rawValue != null) {
      return (Decimal) rawValue;
    }
    return fieldName == 'MFL_AAV__c' ? 0 : 9999;
  }

  private static Decimal average(List<Decimal> values) {
    if (values.isEmpty()) {
      return 0;
    }
    Decimal total = 0;
    for (Decimal value : values) {
      total += value;
    }
    return total / values.size();
  }

  private static Decimal standardDeviation(
    List<Decimal> values,
    Decimal averageValue
  ) {
    if (values.size() < 2) {
      return 0;
    }
    Decimal sumOfSquaredDifferences = 0;
    for (Decimal value : values) {
      sumOfSquaredDifferences +=
        (value - averageValue) * (value - averageValue);
    }
    Double variance = (sumOfSquaredDifferences / values.size()).doubleValue();
    return Decimal.valueOf(Math.sqrt(variance));
  }

  /**
   * Orders Player__c records by a precomputed Decimal value per record
   * Id - either a field read straight off the record (rank fields, via
   * metricValuesByField()) or a derived value with no field of its own
   * (confidence-adjusted auction value, via
   * confidenceAdjustedAuctionValues()). descending=true means the
   * highest value sorts first (used for auction value, where a bigger
   * number is a better player); otherwise the lowest value sorts first
   * (used for rank fields, where 1 is the best player).
   */
  private class ValueComparator implements Comparator<Player__c> {
    private Map<Id, Decimal> values;
    private Boolean descending;

    ValueComparator(Map<Id, Decimal> values, Boolean descending) {
      this.values = values;
      this.descending = descending;
    }

    public Integer compare(Player__c a, Player__c b) {
      Decimal valueA = values.get(a.Id);
      Decimal valueB = values.get(b.Id);
      if (valueA == valueB) {
        return 0;
      }
      Integer result = valueA < valueB ? -1 : 1;
      return descending ? -result : result;
    }
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
    Decimal aavMin = getRawAAVBound(player.id, mapPlayersAAV, true);
    Decimal aavMax = getRawAAVBound(player.id, mapPlayersAAV, false);
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
      AAV_Min__c = aavMin,
      AAV_Max__c = aavMax,
      NFL_Team__c = teamId
    );

    return newPlayer;
  }

  /**
   * MFL's raw Average Auction Value, unweighted for this league. Per
   * MFL's own API docs, it's expressed as a share of a notional $1000
   * pool shared across the WHOLE league (not one team's budget), e.g. 82
   * means "typically ~8.2% of the league's combined auction pool".
   * Defaults to 0 when MFL doesn't return a value for this player,
   * rather than null. Kept as-is, untouched by any of this league's own
   * confidence adjustment - Player__c.Predicted_Auction_Cost__c is what
   * scales a confidence-adjusted version of this to this league's actual
   * budget pool (see predictedAuctionCost()); MFL_AAV__c itself stays
   * the raw number synced from MFL.
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

  /**
   * MFL's minValue/maxValue for TYPE=aav - the range of prices actually
   * paid across the auctions behind averageValue, not just the average
   * itself. A wide min/max spread relative to the average is a sign the
   * "average" is really an uneasy mix of drafters who barely value a
   * player and drafters speculatively overpaying for them (e.g. an
   * unproven rookie), rather than a genuine market consensus -
   * computeTiers() uses this spread to decide how much to trust
   * MFL_AAV__c for tiering. Defaults to the same value as getRawAAV()
   * (0) when MFL doesn't return this player, keeping min/max consistent
   * with the average they'd otherwise be compared against.
   */
  private static Decimal getRawAAVBound(
    String playerId,
    Map<String, AAV_Player> mapPlayersAAV,
    Boolean useMin
  ) {
    if (!mapPlayersAAV.containsKey(playerId)) {
      return 0;
    }
    String bound = useMin
      ? mapPlayersAAV.get(playerId).minValue
      : mapPlayersAAV.get(playerId).maxValue;
    return bound == null ? 0 : Decimal.valueOf(bound);
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
    //Checks AAV min/max spread
    Decimal retrievedAAVMin = getRawAAVBound(player.id, mapPlayersAAV, true);
    Decimal retrievedAAVMax = getRawAAVBound(player.id, mapPlayersAAV, false);
    if (
      retrievedAAVMin != nflPlayers.get(player.id).AAV_Min__c ||
      retrievedAAVMax != nflPlayers.get(player.id).AAV_Max__c
    ) {
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
        AAV_Min__c,
        AAV_Max__c,
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

  /**
   * Top 8 undrafted (Team_Owner__c = NULL) players matching searchTerm
   * (a SOSL search across all fields once 2+ characters are typed, or
   * just the best-ranked undrafted players with no term at all), ordered
   * by whichever rank field this league's Ranking_Option__c prefers -
   * the same rule computeTiers()'s Tier_Rank__c uses, kept consistent so
   * "best available" means the same thing everywhere in the app. Backs
   * the live player search in the draftSelectPick LWC during an actual
   * draft pick.
   */
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
