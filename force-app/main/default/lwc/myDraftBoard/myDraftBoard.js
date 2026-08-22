import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { showToast } from "c/toastUtility";
import getDraftSettings from "@salesforce/apex/LeagueSetup.getDraftSettings";
import getUndraftedPlayers from "@salesforce/apex/ManageMyDraftBoard.getUndraftedPlayers";
import getMyDraftedPlayers from "@salesforce/apex/ManageMyDraftBoard.getMyDraftedPlayers";
import updatePlayerNotes from "@salesforce/apex/ManageMyDraftBoard.updatePlayerNotes";

const POSITIONS = ["QB", "RB", "WR", "TE", "Def", "PK"];
const DRAFT_UPDATED_CHANNEL = "/event/DraftUpdated__e";
const DRAFT_MESSAGE_CHANNEL = "/event/Draft_Message__e";

export default class MyDraftBoard extends LightningElement {
  draftSettings;
  undraftedPlayers;
  myDraftedPlayers;

  undraftedResult;
  myDraftedResult;

  searchTerm = "";
  positionFilter = "ALL";
  nominatedPlayerId;

  positions = POSITIONS;

  draftUpdatedSubscription;
  draftMessageSubscription;

  @wire(getDraftSettings)
  wiredDraftSettings(result) {
    if (result.data) {
      this.draftSettings = result.data;
    }
  }

  @wire(getUndraftedPlayers)
  wiredUndrafted(result) {
    this.undraftedResult = result;
    if (result.data) {
      this.undraftedPlayers = result.data;
    }
  }

  @wire(getMyDraftedPlayers)
  wiredMyDrafted(result) {
    this.myDraftedResult = result;
    if (result.data) {
      this.myDraftedPlayers = result.data;
    }
  }

  connectedCallback() {
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
    onError(this.handleEmpApiError);
  }

  disconnectedCallback() {
    if (this.draftUpdatedSubscription) {
      unsubscribe(this.draftUpdatedSubscription);
    }
    if (this.draftMessageSubscription) {
      unsubscribe(this.draftMessageSubscription);
    }
  }

  handleDraftUpdated = () => {
    refreshApex(this.undraftedResult).then(() => {
      return refreshApex(this.myDraftedResult);
    });
  };

  handleDraftMessage = (response) => {
    const playerId = response?.data?.payload?.Player_Id__c;
    if (playerId) {
      this.nominatedPlayerId = playerId;
    }
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
          refreshApex(this.undraftedResult),
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

  get filteredUndraftedPlayers() {
    if (!this.undraftedPlayers) {
      return [];
    }
    const term = this.searchTerm.toLowerCase();
    return this.undraftedPlayers.filter((player) => {
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

  get groupedUndrafted() {
    const byPosition = new Map();
    this.filteredUndraftedPlayers.forEach((player) => {
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

    const sortedTiers = Array.from(tierMap.keys()).sort((a, b) => a - b);
    const tiers = sortedTiers.map((tier) => ({
      key: `tier-${tier}`,
      label: `Tier ${tier}`,
      players: this.withValueLabels(
        [...tierMap.get(tier)].sort(
          (a, b) => (a[valueField] ?? 0) - (b[valueField] ?? 0)
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

  withValueLabels(players) {
    const valueField = this.valueField;
    const isSnake = this.isSnake;
    return players.map((player) => {
      const rawValue = player[valueField];
      let valueLabel;
      if (rawValue) {
        valueLabel = isSnake ? `Rank ${rawValue}` : `$${rawValue}`;
      }
      return { ...player, valueLabel };
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
      (position) => ({
        position,
        players: byPosition.get(position),
      })
    );
  }

  get nominatedPlayer() {
    if (!this.nominatedPlayerId || !this.undraftedPlayers) {
      return undefined;
    }
    const match = this.undraftedPlayers.find(
      (player) => player.Id === this.nominatedPlayerId
    );
    return match ? this.withValueLabels([match])[0] : undefined;
  }

  get showNominationModal() {
    return !!this.nominatedPlayer;
  }
}
