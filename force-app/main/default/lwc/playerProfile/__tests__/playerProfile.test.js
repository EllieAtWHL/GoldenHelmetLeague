import { createElement } from "lwc";
import PlayerProfile from "c/playerProfile";

const PLAYER = {
  Id: "player1",
  Position__c: "QB",
  MFL_Name__c: "Sample, Player",
  Team__c: "SF",
  Photo_URL_Formula__c: "https://example.com/player1.png",
};

describe("c-player-profile", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createPlayerProfile() {
    const element = createElement("c-player-profile", { is: PlayerProfile });
    element.player = { ...PLAYER };
    document.body.appendChild(element);
    return element;
  }

  it("applies a position-based class and renders player details", () => {
    const element = createPlayerProfile();

    const layout = element.shadowRoot.querySelector("lightning-layout");
    expect(layout.className).toBe("profile QB");
    expect(element.shadowRoot.textContent).toContain("Sample, Player");
    expect(element.shadowRoot.textContent).toContain("SF");
  });

  it("adds an active class to the layout when makeActive is called", () => {
    const element = createPlayerProfile();
    const layout = element.shadowRoot.querySelector("lightning-layout");

    element.makeActive();

    expect(layout.classList.contains("active")).toBe(true);
  });

  it("removes the active class when makeInactive is called", () => {
    const element = createPlayerProfile();
    const layout = element.shadowRoot.querySelector("lightning-layout");

    element.makeActive();
    element.makeInactive();

    expect(layout.classList.contains("active")).toBe(false);
  });
});
