import { createElement } from "lwc";
import AuctionBoard from "c/auctionBoard";

describe("c-auction-board", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders one c-auction-team-view per team, passing the team through", async () => {
    const element = createElement("c-auction-board", { is: AuctionBoard });
    element.draft = {
      teams: [
        { Id: "team1", Team_Name__c: "Team One", picks: [] },
        { Id: "team2", Team_Name__c: "Team Two", picks: [] },
      ],
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const teamViews = element.shadowRoot.querySelectorAll(
      "c-auction-team-view"
    );
    expect(teamViews.length).toBe(2);
    expect(teamViews[0].team).toEqual(element.draft.teams[0]);
    expect(teamViews[1].team).toEqual(element.draft.teams[1]);
  });

  it("renders no team views for an empty team list", async () => {
    const element = createElement("c-auction-board", { is: AuctionBoard });
    element.draft = { teams: [] };
    document.body.appendChild(element);
    await Promise.resolve();

    const teamViews = element.shadowRoot.querySelectorAll(
      "c-auction-team-view"
    );
    expect(teamViews.length).toBe(0);
  });
});
