import { createElement } from "lwc";
import DraftTicker from "c/draftTicker";

describe("c-draft-ticker", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createDraftTicker(isSnake, tickerContent) {
    const element = createElement("c-draft-ticker", { is: DraftTicker });
    element.isSnake = isSnake;
    element.tickerContent = tickerContent;
    document.body.appendChild(element);
    return element;
  }

  it("shows a welcome message when there is no ticker content", () => {
    const element = createDraftTicker(true, []);

    const marquee = element.shadowRoot.querySelector("marquee");
    expect(marquee.textContent).toContain("Golden Helmet League Draft");
  });

  it("formats snake draft picks as round.pick playerName", () => {
    const element = createDraftTicker(true, [
      { roundNumber: 1, roundPickNumber: 3, playerPickedName: "Sample" },
    ]);

    const marquee = element.shadowRoot.querySelector("marquee");
    expect(marquee.textContent).toContain("1.3 Sample");
  });

  it("formats auction draft picks as playerName - £cost, comma separated", () => {
    const element = createDraftTicker(false, [
      { playerPickedName: "First", auctionCost: 10 },
      { playerPickedName: "Second", auctionCost: 20 },
    ]);

    const marquee = element.shadowRoot.querySelector("marquee");
    expect(marquee.textContent).toBe("Recent picks: First - £10, Second - £20");
  });
});
