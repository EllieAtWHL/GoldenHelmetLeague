import { createElement } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe } from "lightning/empApi";
import MyDraftBoard from "c/myDraftBoard";
import getDraftSettings from "@salesforce/apex/LeagueSetup.getDraftSettings";
import getUndraftedPlayers from "@salesforce/apex/ManageMyDraftBoard.getUndraftedPlayers";
import getMyDraftedPlayers from "@salesforce/apex/ManageMyDraftBoard.getMyDraftedPlayers";
import updatePlayerNotes from "@salesforce/apex/ManageMyDraftBoard.updatePlayerNotes";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const UNDRAFTED_PLAYERS = [
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
  },
  {
    Id: "p2",
    MFL_Name__c: "Beta, Bob",
    Position__c: "QB",
    Team__c: "KC",
    Photo_URL_Formula__c: "",
    ADP_Rank__c: 20,
    Experts_Rank__c: 22,
    Predicted_Auction_Cost__c: 5,
    Tier_Rank__c: 2,
    Tier_Auction__c: 2,
    My_notes__c: "",
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

  async function createMyDraftBoard(draftSettings = SNAKE_SETTINGS) {
    const element = createElement("c-my-draft-board", { is: MyDraftBoard });
    document.body.appendChild(element);
    getDraftSettings.emit(draftSettings);
    getUndraftedPlayers.emit([...UNDRAFTED_PLAYERS]);
    getMyDraftedPlayers.emit([...MY_TEAM_PLAYERS]);
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

  it("groups undrafted players by position and tier, labelling value by rank for a snake draft", async () => {
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

    expect(alpha.valueLabel).toBe("$40");
  });

  it("filters the available players list by search term", async () => {
    const element = await createMyDraftBoard();

    const searchInput = element.shadowRoot.querySelector("lightning-input");
    searchInput.value = "beta";
    searchInput.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    const cards = cardsFor(element);
    expect(cards.some((card) => card.player.Id === "p1")).toBe(false);
    expect(cards.some((card) => card.player.Id === "p2")).toBe(true);
  });

  it("refreshes both player wires when a DraftUpdated__e message arrives", async () => {
    await createMyDraftBoard();

    draftUpdatedCallback({});
    await flushPromises();

    expect(refreshApex).toHaveBeenCalledTimes(2);
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
});
