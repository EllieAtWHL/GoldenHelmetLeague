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

  it("labels the notes preview NOTES, styled the same way as the NEWS label", () => {
    const element = createCard();

    const notesPreview = element.shadowRoot.querySelector(".notes-preview");
    const label = notesPreview.querySelector(".field-label");
    expect(label).not.toBeNull();
    expect(label.textContent).toBe("Notes");
  });

  it("does not show the NOTES label when the player has no notes", () => {
    const element = createCard({
      player: { ...PLAYER, My_notes__c: "" },
    });

    const notesPreview = element.shadowRoot.querySelector(".notes-preview");
    expect(notesPreview.querySelector(".field-label")).toBeNull();
  });

  it("does not render a value label when none is supplied", () => {
    const element = createCard({ valueLabel: undefined });

    expect(element.shadowRoot.textContent).not.toContain("Rank 14");
  });

  it("shades the card and adds a drafted class when isDrafted is true", () => {
    const element = createCard({ isDrafted: true });

    const card = element.shadowRoot.querySelector("div");
    expect(card.className).toBe("card WR drafted");
  });

  it("does not add a drafted class when isDrafted is false", () => {
    const element = createCard({ isDrafted: false });

    const card = element.shadowRoot.querySelector("div");
    expect(card.className).toBe("card WR");
  });

  it("shows a Rookie badge when MFL_Status__c is R", () => {
    const element = createCard({
      player: { ...PLAYER, MFL_Status__c: "R" },
    });

    expect(element.shadowRoot.querySelector("lightning-badge")).not.toBeNull();
  });

  it("does not show a Rookie badge for a non-rookie", () => {
    const element = createCard();

    expect(element.shadowRoot.querySelector("lightning-badge")).toBeNull();
  });

  it("shows an injury badge with the status as its label when Injury_Status__c is set", () => {
    const element = createCard({
      player: { ...PLAYER, Injury_Status__c: "Questionable" },
    });

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("Questionable");
  });

  it("does not show an injury badge when Injury_Status__c is blank", () => {
    const element = createCard();

    expect(element.shadowRoot.querySelector("lightning-badge")).toBeNull();
  });

  it("applies the severe style for an Out/IR/Suspended designation", () => {
    const element = createCard({
      player: { ...PLAYER, Injury_Status__c: "Out" },
    });

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge.className).toContain("severe");
  });

  it("applies the caution style for a Questionable/Doubtful designation", () => {
    const element = createCard({
      player: { ...PLAYER, Injury_Status__c: "Questionable" },
    });

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge.className).toContain("caution");
  });

  it("shows both the Rookie badge and the injury badge for a rookie who is also injured", () => {
    const element = createCard({
      player: {
        ...PLAYER,
        MFL_Status__c: "R",
        Injury_Status__c: "Questionable",
      },
    });

    const badges = element.shadowRoot.querySelectorAll("lightning-badge");
    expect(badges.length).toBe(2);
  });

  it("shows the news headline text when both an injury status and a headline are present", () => {
    const element = createCard({
      player: {
        ...PLAYER,
        Injury_Status__c: "Questionable",
        News_Headline__c: "Limited in practice on Wednesday.",
      },
    });

    const headline = element.shadowRoot.querySelector(".news-headline");
    expect(headline).not.toBeNull();
    expect(headline.textContent).toContain("Limited in practice on Wednesday.");
  });

  it("shows headline text even when there is no injury status", () => {
    const element = createCard({
      player: {
        ...PLAYER,
        News_Headline__c: "Had a big day in practice.",
      },
    });

    const headline = element.shadowRoot.querySelector(".news-headline");
    expect(headline).not.toBeNull();
    expect(headline.textContent).toContain("Had a big day in practice.");
  });

  it("shows the news headline in the same area as My notes, not under the player's name", () => {
    const element = createCard({
      player: {
        ...PLAYER,
        News_Headline__c: "Had a big day in practice.",
      },
    });

    const notesCol = element.shadowRoot.querySelector(".notes-col");
    const nameCol = element.shadowRoot.querySelector(".name-col");
    expect(notesCol.querySelector(".news-headline")).not.toBeNull();
    expect(nameCol.querySelector(".news-headline")).toBeNull();
  });

  it("shows both the news headline and the player's own notes together when both exist", () => {
    const element = createCard({
      player: {
        ...PLAYER,
        My_notes__c: "Watch out for a committee backfield.",
        News_Headline__c: "Had a big day in practice.",
      },
    });

    expect(element.shadowRoot.textContent).toContain(
      "Had a big day in practice."
    );
    expect(element.shadowRoot.textContent).toContain(
      "Watch out for a committee backfield."
    );
  });

  it("does not show headline text when there is none, even with an injury status", () => {
    const element = createCard({
      player: { ...PLAYER, Injury_Status__c: "Questionable" },
    });

    expect(element.shadowRoot.querySelector(".news-headline")).toBeNull();
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
