import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { loadStyle } from "lightning/platformResourceLoader";
import { showToast } from "c/toastUtility";
import getDraftSettings from "@salesforce/apex/LeagueSetup.getDraftSettings";
import getAllPlayers from "@salesforce/apex/ManageMyDraftBoard.getAllPlayers";
import getMyDraftedPlayers from "@salesforce/apex/ManageMyDraftBoard.getMyDraftedPlayers";
import updatePlayerNotes from "@salesforce/apex/ManageMyDraftBoard.updatePlayerNotes";
import getTeams from "@salesforce/apex/MFLManageOwners.getTeams";
import refreshAllPlayerNews from "@salesforce/apex/PlayerNewsService.refreshAllPlayerNews";
import HIDE_DRAFT_BOARD_HEADER from "@salesforce/resourceUrl/hideDraftBoardHeader";

const POSITIONS = ["QB", "RB", "WR", "TE", "Def", "PK"];
const DRAFT_UPDATED_CHANNEL = "/event/DraftUpdated__e";
const DRAFT_MESSAGE_CHANNEL = "/event/Draft_Message__e";
const PLAYER_NEWS_UPDATED_CHANNEL = "/event/Player_News_Updated__e";

export default class MyDraftBoard extends LightningElement {
  draftSettings;
  allPlayers;
  myDraftedPlayers;
  teams;

  allPlayersResult;
  myDraftedResult;
  teamsResult;

  searchTerm = "";
  positionFilter = "ALL";
  nominatedPlayerId;
  isRefreshingNews = false;

  positions = POSITIONS;

  draftUpdatedSubscription;
  draftMessageSubscription;
  playerNewsUpdatedSubscription;

  @wire(getDraftSettings)
  wiredDraftSettings(result) {
    if (result.data) {
      this.draftSettings = result.data;
    }
  }

  @wire(getAllPlayers)
  wiredAllPlayers(result) {
    this.allPlayersResult = result;
    if (result.data) {
      this.allPlayers = result.data;
    }
  }

  @wire(getMyDraftedPlayers)
  wiredMyDrafted(result) {
    this.myDraftedResult = result;
    if (result.data) {
      this.myDraftedPlayers = result.data;
    }
  }

  @wire(getTeams)
  wiredTeams(result) {
    this.teamsResult = result;
    if (result.data) {
      this.teams = result.data;
    }
  }

  connectedCallback() {
    // The standard Lightning App Page header just duplicates this card's
    // own "My Draft Board" title beneath it.
    loadStyle(this, HIDE_DRAFT_BOARD_HEADER).catch((error) => {
      console.log(
        "Unable to load hideDraftBoardHeader style",
        JSON.stringify(error)
      );
    });
    subscribe(DRAFT_UPDATED_CHANNEL, -1, this.handleDraftUpdated).then(
      (response) => {
        this.draftUpdatedSubscription = response;
      }
    );
    subscribe(DRAFT_MESSAGE_CHANNEL, -1, this.handleDraftMessage).then(
      (response) => {
        this.draftMessageSubscription = response;
      }
    );
    subscribe(
      PLAYER_NEWS_UPDATED_CHANNEL,
      -1,
      this.handlePlayerNewsUpdated
    ).then((response) => {
      this.playerNewsUpdatedSubscription = response;
    });
    onError(this.handleEmpApiError);
  }

  disconnectedCallback() {
    if (this.draftUpdatedSubscription) {
      unsubscribe(this.draftUpdatedSubscription);
    }
    if (this.draftMessageSubscription) {
      unsubscribe(this.draftMessageSubscription);
    }
    if (this.playerNewsUpdatedSubscription) {
      unsubscribe(this.playerNewsUpdatedSubscription);
    }
  }

  handleDraftUpdated = () => {
    refreshApex(this.allPlayersResult).then(() => {
      return Promise.all([
        refreshApex(this.myDraftedResult),
        refreshApex(this.teamsResult),
      ]);
    });
  };

  handleDraftMessage = (response) => {
    const playerId = response?.data?.payload?.Player_Id__c;
    if (playerId) {
      this.nominatedPlayerId = playerId;
    }
  };

  handlePlayerNewsUpdated = () => {
    refreshApex(this.allPlayersResult);
  };

  // eslint-disable-next-line class-methods-use-this
  handleEmpApiError = (error) => {
    console.log(JSON.stringify(error));
  };

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
  }

  handlePositionFilter(event) {
    this.positionFilter = event.target.dataset.position;
  }

  handleNotesSave(event) {
    const { playerId, notes } = event.detail;
    updatePlayerNotes({ playerId, notes })
      .then(() => {
        return Promise.all([
          refreshApex(this.allPlayersResult),
          refreshApex(this.myDraftedResult),
        ]);
      })
      .then(() => {
        showToast("Notes saved", null, "success");
      })
      .catch((error) => {
        showToast("Unable to save notes", error?.body?.message, "error");
      });
  }

  handleCloseNomination() {
    this.nominatedPlayerId = undefined;
  }

  handleRefreshNews() {
    this.isRefreshingNews = true;
    refreshAllPlayerNews()
      .then(() => {
        return Promise.all([
          refreshApex(this.allPlayersResult),
          refreshApex(this.myDraftedResult),
        ]).then(() =>
          showToast(
            "Injury statuses refreshed — detailed news will fill in over the next few minutes",
            null,
            "success"
          )
        );
      })
      .catch((error) => {
        showToast(
          "Unable to refresh player news",
          error?.body?.message,
          "error"
        );
      })
      .finally(() => {
        this.isRefreshingNews = false;
      });
  }

  get isSnake() {
    return this.draftSettings?.Draft_Type__c === "snake";
  }

  get valueField() {
    if (this.isSnake) {
      return this.draftSettings?.Ranking_Option__c === "Fantasy Sharks"
        ? "Experts_Rank__c"
        : "ADP_Rank__c";
    }
    return "Predicted_Auction_Cost__c";
  }

  get tierField() {
    return this.isSnake ? "Tier_Rank__c" : "Tier_Auction__c";
  }

  get positionPills() {
    return ["ALL", ...POSITIONS].map((position) => ({
      position,
      variant: position === this.positionFilter ? "brand" : "neutral",
    }));
  }

  get filteredAllPlayers() {
    if (!this.allPlayers) {
      return [];
    }
    const term = this.searchTerm.toLowerCase();
    return this.allPlayers.filter((player) => {
      if (
        this.positionFilter !== "ALL" &&
        player.Position__c !== this.positionFilter
      ) {
        return false;
      }
      if (term && !player.MFL_Name__c?.toLowerCase().includes(term)) {
        return false;
      }
      return true;
    });
  }

  get groupedAllPlayers() {
    const byPosition = new Map();
    this.filteredAllPlayers.forEach((player) => {
      if (!byPosition.has(player.Position__c)) {
        byPosition.set(player.Position__c, []);
      }
      byPosition.get(player.Position__c).push(player);
    });

    return POSITIONS.filter((position) => byPosition.has(position)).map(
      (position) => {
        const tiers = this.groupByTier(byPosition.get(position));
        return {
          position,
          tiers,
          activeSections: tiers
            .filter((tier) => tier.key !== "unranked")
            .map((tier) => tier.key),
        };
      }
    );
  }

  groupByTier(players) {
    const valueField = this.valueField;
    const tierField = this.tierField;
    const tierMap = new Map();
    const unranked = [];

    players.forEach((player) => {
      const value = player[valueField];
      if (!value) {
        unranked.push(player);
        return;
      }
      const tier = player[tierField];
      const tierKey = tier === null || tier === undefined ? "unranked" : tier;
      if (!tierMap.has(tierKey)) {
        tierMap.set(tierKey, []);
      }
      tierMap.get(tierKey).push(player);
    });

    // Rank fields: lower is better, so ascending puts the best player first.
    // Predicted_Auction_Cost__c: higher is better, so flip to descending.
    const sortDirection = this.isSnake ? 1 : -1;

    const sortedTiers = Array.from(tierMap.keys()).sort((a, b) => a - b);
    const tiers = sortedTiers.map((tier) => ({
      key: `tier-${tier}`,
      label: `Tier ${tier}`,
      players: this.withValueLabels(
        [...tierMap.get(tier)].sort(
          (a, b) =>
            sortDirection * ((a[valueField] ?? 0) - (b[valueField] ?? 0))
        )
      ),
    }));

    if (unranked.length) {
      tiers.push({
        key: "unranked",
        label: "Unranked / Replacement Level",
        players: this.withValueLabels(unranked),
      });
    }

    return tiers;
  }

  // Apex serializes a subquery as { totalSize, done, records: [...] }, but
  // handle a flat array too in case that ever changes - cheap to be safe here.
  // eslint-disable-next-line class-methods-use-this
  firstPick(player) {
    const picks = player.Picks__r;
    if (Array.isArray(picks)) {
      return picks[0];
    }
    return picks?.records?.[0];
  }

  // eslint-disable-next-line class-methods-use-this
  formatCurrency(value) {
    return `£${Number(value).toFixed(2)}`;
  }

  withValueLabels(players) {
    const valueField = this.valueField;
    const isSnake = this.isSnake;
    return players.map((player) => {
      const isDrafted = !!player.Team_Owner__c;
      const pick = this.firstPick(player);
      let valueLabel;
      if (isDrafted) {
        if (isSnake) {
          valueLabel = pick
            ? `Drafted Rd ${pick.Round__c}.${pick.Round_Pick_Number__c}`
            : "Drafted";
        } else {
          valueLabel =
            pick?.Auction_Cost__c != null
              ? `Sold ${this.formatCurrency(pick.Auction_Cost__c)}`
              : "Drafted";
        }
      } else {
        const rawValue = player[valueField];
        if (rawValue) {
          valueLabel = isSnake
            ? `Rank ${rawValue}`
            : this.formatCurrency(rawValue);
        }
      }
      return { ...player, valueLabel, isDrafted };
    });
  }

  get groupedMyTeam() {
    if (!this.myDraftedPlayers) {
      return [];
    }
    const byPosition = new Map();
    this.myDraftedPlayers.forEach((player) => {
      if (!byPosition.has(player.Position__c)) {
        byPosition.set(player.Position__c, []);
      }
      byPosition.get(player.Position__c).push(player);
    });

    return POSITIONS.filter((position) => byPosition.has(position)).map(
      (position) => {
        const players = this.withValueLabels(byPosition.get(position));
        return {
          position,
          count: players.length,
          players,
        };
      }
    );
  }

  get nominatedPlayer() {
    if (!this.nominatedPlayerId || !this.allPlayers) {
      return undefined;
    }
    const match = this.allPlayers.find(
      (player) => player.Id === this.nominatedPlayerId
    );
    if (!match || match.Team_Owner__c) {
      return undefined;
    }
    return this.withValueLabels([match])[0];
  }

  get showNominationModal() {
    return !!this.nominatedPlayer;
  }

  get myTeam() {
    return this.teams?.find((team) => team.Is_My_Team__c);
  }

  get showBudgetSummary() {
    return !this.isSnake && !!this.myTeam;
  }

  get showPotentialNominations() {
    return !this.isSnake;
  }

  get potentialNominations() {
    if (!this.allPlayers) {
      return [];
    }
    const undrafted = this.allPlayers.filter((player) => !player.Team_Owner__c);
    const sorted = [...undrafted].sort(
      (a, b) =>
        (b.Predicted_Auction_Cost__c ?? 0) - (a.Predicted_Auction_Cost__c ?? 0)
    );
    return this.withValueLabels(sorted.slice(0, 15));
  }

  get budgetRemaining() {
    return this.myTeam?.Remaining_Budget__c;
  }

  get spendByPosition() {
    const totals = new Map();
    (this.myDraftedPlayers || []).forEach((player) => {
      const pick = this.firstPick(player);
      const spent = pick?.Auction_Cost__c || 0;
      totals.set(
        player.Position__c,
        (totals.get(player.Position__c) || 0) + spent
      );
    });
    return POSITIONS.filter((position) => totals.has(position)).map(
      (position) => ({
        position,
        key: position,
        spent: this.formatCurrency(totals.get(position)),
      })
    );
  }
}
