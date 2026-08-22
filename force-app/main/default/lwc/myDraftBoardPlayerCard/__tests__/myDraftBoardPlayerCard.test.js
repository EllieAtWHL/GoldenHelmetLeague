import { createElement } from "lwc";
import MyDraftBoardPlayerCard from "c/myDraftBoardPlayerCard";

const PLAYER = {
  Id: "player1",
  Position__c: "WR",
  MFL_Name__c: "Sample, Player",
  Team__c: "SF",
  Photo_URL_Formula__c: "https://example.com/player1.png",
  My_notes__c: "Existing note",
};

describe("c-my-draft-board-player-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createCard(overrides = {}) {
    const element = createElement("c-my-draft-board-player-card", {
      is: MyDraftBoardPlayerCard,
    });
    element.player = { ...PLAYER };
    element.valueLabel = "Rank 14";
    Object.assign(element, overrides);
    document.body.appendChild(element);
    return element;
  }

  function findButtonByLabel(element, label) {
    return Array.from(
      element.shadowRoot.querySelectorAll("lightning-button")
    ).find((button) => button.label === label);
  }

  it("applies a position-based class and renders player details and value label", () => {
    const element = createCard();

    const card = element.shadowRoot.querySelector("div");
    expect(card.className).toBe("card WR");
    expect(element.shadowRoot.textContent).toContain("Sample, Player");
    expect(element.shadowRoot.textContent).toContain("SF");
    expect(element.shadowRoot.textContent).toContain("Rank 14");
    expect(element.shadowRoot.textContent).toContain("Existing note");
  });

  it("does not render a value label when none is supplied", () => {
    const element = createCard({ valueLabel: undefined });

    expect(element.shadowRoot.textContent).not.toContain("Rank 14");
  });

  it("dispatches notessave with the edited text when Save is clicked", async () => {
    const element = createCard();
    const notesSaveHandler = jest.fn();
    element.addEventListener("notessave", notesSaveHandler);

    findButtonByLabel(element, "Edit notes").click();
    await Promise.resolve();

    const textarea = element.shadowRoot.querySelector("lightning-textarea");
    textarea.dispatchEvent(
      new CustomEvent("change", { detail: { value: "New note text" } })
    );
    await Promise.resolve();

    findButtonByLabel(element, "Save").click();
    await Promise.resolve();

    expect(notesSaveHandler).toHaveBeenCalledTimes(1);
    expect(notesSaveHandler.mock.calls[0][0].detail).toEqual({
      playerId: "player1",
      notes: "New note text",
    });
  });

  it("discards the edit and returns to read-only view on Cancel", async () => {
    const element = createCard();

    findButtonByLabel(element, "Edit notes").click();
    await Promise.resolve();

    expect(
      element.shadowRoot.querySelector("lightning-textarea")
    ).not.toBeNull();

    findButtonByLabel(element, "Cancel").click();
    await Promise.resolve();

    expect(element.shadowRoot.querySelector("lightning-textarea")).toBeNull();
    expect(element.shadowRoot.textContent).toContain("Existing note");
  });
});
