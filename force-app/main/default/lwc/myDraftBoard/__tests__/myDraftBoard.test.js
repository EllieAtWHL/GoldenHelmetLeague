import { createElement } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe } from "lightning/empApi";
import MyDraftBoard from "c/myDraftBoard";
import getDraftSettings from "@salesforce/apex/LeagueSetup.getDraftSettings";
import getAllPlayers from "@salesforce/apex/ManageMyDraftBoard.getAllPlayers";
import getMyDraftedPlayers from "@salesforce/apex/ManageMyDraftBoard.getMyDraftedPlayers";
import updatePlayerNotes from "@salesforce/apex/ManageMyDraftBoard.updatePlayerNotes";
import getTeams from "@salesforce/apex/MFLManageOwners.getTeams";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

function picksOf(...records) {
  return { records };
}

const ALL_PLAYERS = [
  {
    Id: "p1",
    MFL_Name__c: "Alpha, Anna",
    Position__c: "QB",
    Team__c: "SF",
    Photo_URL_Formula__c: "",
    ADP_Rank__c: 5,
    Experts_Rank__c: 4,
    Predicted_Auction_Cost__c: 40,
    Tier_Rank__c: 1,
    Tier_Auction__c: 1,
    My_notes__c: "",
    Team_Owner__c: null,
    Picks__r: picksOf(),
  },
  {
    Id: "p2",
    MFL_Name__c: "Beta, Bob",
    Position__c: "QB",
    Team__c: "KC",
    Photo_URL_Formula__c: "",
    ADP_Rank__c: 8,
    Experts_Rank__c: 9,
    Predicted_Auction_Cost__c: 25,
    Tier_Rank__c: 1,
    Tier_Auction__c: 1,
    My_notes__c: "",
    Team_Owner__c: null,
    Picks__r: picksOf(),
  },
  {
    Id: "p3",
    MFL_Name__c: "Gamma, Gary",
    Position__c: "RB",
    Team__c: "DAL",
    Photo_URL_Formula__c: "",
    ADP_Rank__c: null,
    Experts_Rank__c: null,
    Predicted_Auction_Cost__c: 0,
    Tier_Rank__c: null,
    Tier_Auction__c: null,
    My_notes__c: "",
    Team_Owner__c: null,
    Picks__r: picksOf(),
    MFL_Status__c: "R",
  },
  {
    Id: "p4",
    MFL_Name__c: "Delta, Dana",
    Position__c: "WR",
    Team__c: "MIA",
    Photo_URL_Formula__c: "",
    ADP_Rank__c: 12,
    Experts_Rank__c: 11,
    Predicted_Auction_Cost__c: 18,
    Tier_Rank__c: 1,
    Tier_Auction__c: 1,
    My_notes__c: "",
    Team_Owner__c: "team1",
    Picks__r: picksOf({
      Auction_Cost__c: 22,
      Round__c: 3,
      Round_Pick_Number__c: 5,
    }),
  },
];

const MY_TEAM_PLAYERS = [
  {
    Id: "p4",
    MFL_Name__c: "Delta, Dana",
    Position__c: "WR",
    Team__c: "MIA",
    Photo_URL_Formula__c: "",
    My_notes__c: "",
    Team_Owner__c: "team1",
    Picks__r: picksOf({
      Auction_Cost__c: 22,
      Round__c: 3,
      Round_Pick_Number__c: 5,
    }),
  },
  {
    Id: "p5",
    MFL_Name__c: "Epsilon, Ed",
    Position__c: "RB",
    Team__c: "NYJ",
    Photo_URL_Formula__c: "",
    My_notes__c: "",
    Team_Owner__c: "team1",
    Picks__r: picksOf({
      Auction_Cost__c: 8,
      Round__c: 9,
      Round_Pick_Number__c: 2,
    }),
  },
];

const TEAMS = [
  {
    Id: "team1",
    Team_Name__c: "My Team",
    Remaining_Budget__c: 178,
    Is_My_Team__c: true,
  },
  {
    Id: "team2",
    Team_Name__c: "Rival Team",
    Remaining_Budget__c: 150,
    Is_My_Team__c: false,
  },
];

const SNAKE_SETTINGS = { Draft_Type__c: "snake", Ranking_Option__c: "ADP" };
const AUCTION_SETTINGS = { Draft_Type__c: "auction" };

describe("c-my-draft-board", () => {
  let draftUpdatedCallback;
  let draftMessageCallback;

  beforeEach(() => {
    draftUpdatedCallback = undefined;
    draftMessageCallback = undefined;
    subscribe.mockImplementation((channel, replayId, callback) => {
      if (channel === "/event/DraftUpdated__e") {
        draftUpdatedCallback = callback;
      } else if (channel === "/event/Draft_Message__e") {
        draftMessageCallback = callback;
      }
      return Promise.resolve({});
    });
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  async function createMyDraftBoard(
    draftSettings = SNAKE_SETTINGS,
    allPlayers = ALL_PLAYERS
  ) {
    const element = createElement("c-my-draft-board", { is: MyDraftBoard });
    document.body.appendChild(element);
    getDraftSettings.emit(draftSettings);
    getAllPlayers.emit([...allPlayers]);
    getMyDraftedPlayers.emit([...MY_TEAM_PLAYERS]);
    getTeams.emit([...TEAMS]);
    await flushPromises();
    return element;
  }

  function cardsFor(element) {
    return Array.from(
      element.shadowRoot.querySelectorAll("c-my-draft-board-player-card")
    );
  }

  it("subscribes to DraftUpdated__e and Draft_Message__e on connect, and unsubscribes on disconnect", async () => {
    const element = await createMyDraftBoard();

    expect(subscribe).toHaveBeenCalledWith(
      "/event/DraftUpdated__e",
      -1,
      expect.any(Function)
    );
    expect(subscribe).toHaveBeenCalledWith(
      "/event/Draft_Message__e",
      -1,
      expect.any(Function)
    );

    document.body.removeChild(element);
    expect(unsubscribe).toHaveBeenCalledTimes(2);
  });

  it("groups players by position and tier, labelling value by rank for a snake draft", async () => {
    const element = await createMyDraftBoard(SNAKE_SETTINGS);

    const cards = cardsFor(element);
    const alpha = cards.find((card) => card.player.Id === "p1");
    const gamma = cards.find((card) => card.player.Id === "p3");

    expect(alpha.valueLabel).toBe("Rank 5");
    expect(gamma.valueLabel).toBeUndefined();

    const unrankedSection = Array.from(
      element.shadowRoot.querySelectorAll("lightning-accordion-section")
    ).find((section) => section.label === "Unranked / Replacement Level");
    expect(unrankedSection).not.toBeUndefined();
  });

  it("labels value by Predicted Auction Cost for an auction draft", async () => {
    const element = await createMyDraftBoard(AUCTION_SETTINGS);

    const cards = cardsFor(element);
    const alpha = cards.find((card) => card.player.Id === "p1");

    expect(alpha.valueLabel).toBe("£40.00");
  });

  it("sorts players within a tier by lowest rank first for a snake draft", async () => {
    const element = await createMyDraftBoard(SNAKE_SETTINGS);

    const qbCards = cardsFor(element).filter(
      (card) => card.player.Position__c === "QB"
    );
    expect(qbCards.map((card) => card.player.Id)).toEqual(["p1", "p2"]);
  });

  it("sorts players within a tier by highest auction value first for an auction draft", async () => {
    const element = await createMyDraftBoard(AUCTION_SETTINGS);

    const qbCards = cardsFor(element).filter(
      (card) => card.player.Position__c === "QB"
    );
    expect(qbCards.map((card) => card.player.Id)).toEqual(["p1", "p2"]);
    expect(qbCards.map((card) => card.valueLabel)).toEqual([
      "£40.00",
      "£25.00",
    ]);
  });

  it("shows a drafted player shaded, with their actual sold price instead of a predicted value", async () => {
    const element = await createMyDraftBoard(AUCTION_SETTINGS);

    const delta = cardsFor(element).find((card) => card.player.Id === "p4");

    expect(delta.isDrafted).toBe(true);
    expect(delta.valueLabel).toBe("Sold £22.00");
  });

  it("shows a drafted player's round/pick instead of rank for a snake draft", async () => {
    const element = await createMyDraftBoard(SNAKE_SETTINGS);

    const delta = cardsFor(element).find((card) => card.player.Id === "p4");

    expect(delta.isDrafted).toBe(true);
    expect(delta.valueLabel).toBe("Drafted Rd 3.5");
  });

  it("also reads the sold price when Picks__r comes back as a flat array rather than a records wrapper", async () => {
    const flatPicksPlayers = ALL_PLAYERS.map((player) => {
      if (player.Id !== "p4") {
        return player;
      }
      return {
        ...player,
        Picks__r: [
          { Auction_Cost__c: 22, Round__c: 3, Round_Pick_Number__c: 5 },
        ],
      };
    });
    const element = await createMyDraftBoard(
      AUCTION_SETTINGS,
      flatPicksPlayers
    );

    const delta = cardsFor(element).find((card) => card.player.Id === "p4");

    expect(delta.valueLabel).toBe("Sold £22.00");
  });

  it("filters the player list by search term", async () => {
    const element = await createMyDraftBoard();

    const searchInput = element.shadowRoot.querySelector("lightning-input");
    searchInput.value = "beta";
    searchInput.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    const cards = cardsFor(element);
    expect(cards.some((card) => card.player.Id === "p1")).toBe(false);
    expect(cards.some((card) => card.player.Id === "p2")).toBe(true);
  });

  it("refreshes players and teams when a DraftUpdated__e message arrives", async () => {
    await createMyDraftBoard();

    draftUpdatedCallback({});
    await flushPromises();

    expect(refreshApex).toHaveBeenCalledTimes(3);
  });

  it("opens the nomination overlay for the player named in a Draft_Message__e message", async () => {
    const element = await createMyDraftBoard();

    expect(element.shadowRoot.querySelector(".nomination-overlay")).toBeNull();

    draftMessageCallback({ data: { payload: { Player_Id__c: "p2" } } });
    await flushPromises();

    const overlay = element.shadowRoot.querySelector(".nomination-overlay");
    expect(overlay).not.toBeNull();
    const card = overlay.querySelector("c-my-draft-board-player-card");
    expect(card.player.MFL_Name__c).toBe("Beta, Bob");
  });

  it("does not show a nomination overlay for a player who is already drafted", async () => {
    const element = await createMyDraftBoard();

    draftMessageCallback({ data: { payload: { Player_Id__c: "p4" } } });
    await flushPromises();

    expect(element.shadowRoot.querySelector(".nomination-overlay")).toBeNull();
  });

  it("closes the nomination overlay when the close button is clicked", async () => {
    const element = await createMyDraftBoard();

    draftMessageCallback({ data: { payload: { Player_Id__c: "p2" } } });
    await flushPromises();

    element.shadowRoot.querySelector(".close-button").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".nomination-overlay")).toBeNull();
  });

  it("saves notes and refreshes both player wires when a card fires notessave", async () => {
    const element = await createMyDraftBoard();

    const card = cardsFor(element).find((c) => c.player.Id === "p1");
    card.dispatchEvent(
      new CustomEvent("notessave", {
        detail: { playerId: "p1", notes: "Watch injury report" },
      })
    );
    await flushPromises();
    await flushPromises();

    expect(updatePlayerNotes).toHaveBeenCalledWith({
      playerId: "p1",
      notes: "Watch injury report",
    });
    expect(refreshApex).toHaveBeenCalledTimes(2);
  });

  it("shows the budget summary with remaining budget and spend by position for an auction draft", async () => {
    const element = await createMyDraftBoard(AUCTION_SETTINGS);

    const summary = element.shadowRoot.querySelector(".budget-summary");
    expect(summary).not.toBeNull();

    const budgetNumber = element.shadowRoot.querySelector(
      "lightning-formatted-number"
    );
    expect(budgetNumber.value).toBe(178);

    const chips = Array.from(
      element.shadowRoot.querySelectorAll(".spend-chip")
    ).map((chip) => chip.textContent.trim());
    expect(chips).toEqual(["RB: £8.00", "WR: £22.00"]);
  });

  it("hides the budget summary for a snake draft", async () => {
    const element = await createMyDraftBoard(SNAKE_SETTINGS);

    expect(element.shadowRoot.querySelector(".budget-summary")).toBeNull();
  });

  it("shows the sold price and a per-position roster count on the My Team tab", async () => {
    const element = await createMyDraftBoard(AUCTION_SETTINGS);

    const headings = Array.from(
      element.shadowRoot.querySelectorAll(".position-heading")
    ).map((heading) => heading.textContent.trim());
    expect(headings).toContain("WR (1)");
    expect(headings).toContain("RB (1)");

    const delta = cardsFor(element).find((card) => card.player.Id === "p4");
    expect(delta.valueLabel).toBe("Sold £22.00");
  });
});
