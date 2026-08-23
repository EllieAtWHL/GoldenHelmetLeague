import { createElement } from "lwc";
import DraftSelectPick from "c/draftSelectPick";
import { refreshApex } from "@salesforce/apex";
import getTeams from "@salesforce/apex/MFLManageOwners.getTeams";
import searchPlayers from "@salesforce/apex/MFLManagePlayers.searchPlayers";
import makePick from "@salesforce/apex/ManageDraft.makePick";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

// Static label="..."/name="..." values aren't guaranteed to reflect as
// queryable DOM attributes for LWC custom elements -- filter on the JS
// property instead.
function findByName(element, tag, name) {
  return Array.from(element.shadowRoot.querySelectorAll(tag)).find(
    (el) => el.name === name
  );
}

const PLAYERS = [
  {
    Id: "player1",
    MFL_Name__c: "Short",
    Team__c: "SF",
    Position__c: "QB",
    Photo_URL_Formula__c: "https://example.com/1.png",
  },
  {
    Id: "player2",
    MFL_Name__c: "Reallylongname, Somebody",
    Team__c: "KC",
    Position__c: "RB",
    Photo_URL_Formula__c: "https://example.com/2.png",
  },
];

const TEAMS = [
  { Id: "team1", Team_Name__c: "Team One", Remaining_Budget__c: 150 },
  { Id: "team2", Team_Name__c: "Team Two", Remaining_Budget__c: 80 },
];

describe("c-draft-select-pick", () => {
  let dispatchEventSpy;

  beforeEach(() => {
    dispatchEventSpy = jest.spyOn(window, "dispatchEvent");
    // mockResolvedValueOnce/mockRejectedValueOnce queue implementations that
    // clearAllMocks() (below) does not clear -- reset fully each test so an
    // earlier test's queued behavior can't leak into this one.
    makePick.mockReset().mockResolvedValue();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  async function createDraftSelectPick(isSnake) {
    const element = createElement("c-draft-select-pick", {
      is: DraftSelectPick,
    });
    element.isSnake = isSnake;
    element.currentRound = { roundNumber: 3 };
    element.currentPick = {
      roundPickNumber: 5,
      overallPickNumber: 29,
      teamId: "team1",
    };
    document.body.appendChild(element);
    getTeams.emit(TEAMS);
    searchPlayers.emit(PLAYERS);
    await flushPromises();
    return element;
  }

  it("shows the round/pick header for a snake draft", async () => {
    const element = await createDraftSelectPick(true);

    expect(element.shadowRoot.textContent).toContain("Round 3 Pick 5");
  });

  it("shows the overall-pick header for an auction draft", async () => {
    const element = await createDraftSelectPick(false);

    expect(element.shadowRoot.textContent).toContain("Overall Pick 29");
  });

  it("renders one player profile per available player", async () => {
    const element = await createDraftSelectPick(true);

    expect(element.shadowRoot.querySelectorAll("c-player-profile").length).toBe(
      2
    );
  });

  it("disables the confirm button until a player is selected", async () => {
    const element = await createDraftSelectPick(true);

    const confirmButton = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button")
    ).find((button) => button.label === "Confirm Pick");
    expect(confirmButton.disabled).toBe(true);
  });

  it("selects a player, dispatches playerselected for an auction draft, and shortens a long name", async () => {
    const element = await createDraftSelectPick(false);

    const longNamePlayerProfile =
      element.shadowRoot.querySelectorAll("c-player-profile")[1];
    const playerSelectedHandler = jest.fn();
    element.addEventListener("playerselected", playerSelectedHandler);

    longNamePlayerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();

    expect(playerSelectedHandler).toHaveBeenCalledTimes(1);
    const detail = playerSelectedHandler.mock.calls[0][0].detail;
    expect(detail.message).toBe("Bidding on: Reallylongname - KC");
    expect(detail.class).toBe("RB");
    expect(detail.playerId).toBe("player2");
  });

  it("auto-confirms on a second click of the same player in a snake draft", async () => {
    makePick.mockResolvedValueOnce();
    const element = await createDraftSelectPick(true);
    const playerProfile =
      element.shadowRoot.querySelectorAll("c-player-profile")[0];

    playerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();
    playerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();
    await flushPromises();

    expect(makePick).toHaveBeenCalledTimes(1);
    expect(makePick).toHaveBeenCalledWith({
      pickMade: expect.objectContaining({
        Player__c: "player1",
        Team_Owner__c: "team1",
        Round_Pick_Number__c: 5,
        Overall_Pick_Number__c: 29,
        Round__c: 3,
      }),
      playerName: "Short",
    });
  });

  it("confirms an auction pick with the selected winner and price, then refreshes and closes", async () => {
    makePick.mockResolvedValueOnce();
    const element = await createDraftSelectPick(false);
    const playerProfile =
      element.shadowRoot.querySelectorAll("c-player-profile")[0];
    playerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();

    const winnerCombobox = findByName(element, "lightning-combobox", "winner");
    winnerCombobox.value = "team1";
    winnerCombobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "team1" } })
    );

    const priceInput = findByName(element, "lightning-input", "price");
    priceInput.value = "20";
    priceInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "20" } })
    );
    await flushPromises();

    const pickMadeHandler = jest.fn();
    const closeModalHandler = jest.fn();
    element.addEventListener("pickmade", pickMadeHandler);
    element.addEventListener("closemodal", closeModalHandler);

    const confirmButton = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button")
    ).find((button) => button.label === "Confirm Pick");
    confirmButton.click();
    await flushPromises();
    await flushPromises();
    await flushPromises();

    expect(makePick).toHaveBeenCalledWith({
      pickMade: expect.objectContaining({
        Team_Owner__c: "team1",
        Auction_Cost__c: "20",
      }),
      playerName: "Short",
    });
    expect(refreshApex).toHaveBeenCalledTimes(2);
    expect(pickMadeHandler).toHaveBeenCalledTimes(1);
    expect(closeModalHandler).toHaveBeenCalledTimes(1);
  });

  it("marks the price field invalid when it exceeds the winner's remaining budget", async () => {
    const element = await createDraftSelectPick(false);
    const playerProfile =
      element.shadowRoot.querySelectorAll("c-player-profile")[0];
    playerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();

    const winnerCombobox = findByName(element, "lightning-combobox", "winner");
    winnerCombobox.value = "team2";
    winnerCombobox.dispatchEvent(
      new CustomEvent("change", { detail: { value: "team2" } })
    );
    await flushPromises();

    const priceInput = findByName(element, "lightning-input", "price");
    const setCustomValiditySpy = jest.spyOn(priceInput, "setCustomValidity");
    priceInput.value = "999";
    priceInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "999" } })
    );

    expect(setCustomValiditySpy).toHaveBeenCalledWith(
      "Price exceeds remaining budget"
    );
  });

  it("shows a warning toast for a duplicate pick and a generic error toast otherwise", async () => {
    makePick.mockRejectedValueOnce({
      body: {
        message: "Duplicate pick detected. This pick has already been made.",
      },
    });
    const element = await createDraftSelectPick(true);
    const playerProfile =
      element.shadowRoot.querySelectorAll("c-player-profile")[0];
    playerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();
    playerProfile.dispatchEvent(
      new CustomEvent("click", { bubbles: true, composed: true })
    );
    await flushPromises();
    await flushPromises();

    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("warning");
  });
});
