import { createElement } from "lwc";
import AuctionTeamView from "c/auctionTeamView";

function buildTeam(picks) {
  return {
    Id: "team1",
    Team_Name__c: "Team One",
    Icon_URL__c: "https://example.com/icon.png",
    Remaining_Budget__c: 150,
    picks,
  };
}

describe("c-auction-team-view", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("pads the pick list to 17 rows with empty placeholder picks", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    element.team = buildTeam([
      { overallPickNumber: 1, playerPickedName: "A", cssClass: "QB" },
    ]);
    document.body.appendChild(element);

    const rows = element.shadowRoot.querySelectorAll("tbody td");
    expect(rows.length).toBe(17);
  });

  it("does not pad a team that already has 17 picks", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    const picks = Array.from({ length: 17 }, (_, i) => ({
      overallPickNumber: i + 1,
      playerPickedName: `Player ${i}`,
      cssClass: "QB",
    }));
    element.team = buildTeam(picks);
    document.body.appendChild(element);

    const rows = element.shadowRoot.querySelectorAll("tbody td");
    expect(rows.length).toBe(17);
  });

  it("shortens a player name longer than 15 characters to the text before the first comma", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    element.team = buildTeam([
      {
        overallPickNumber: 1,
        playerPickedName: "Reallylongname, Somebody",
        cssClass: "QB",
      },
    ]);
    document.body.appendChild(element);

    const rendered = element.shadowRoot.querySelector("tbody tr b");
    expect(rendered.textContent).toBe("Reallylongname");
  });

  it("leaves a short player name unchanged", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    element.team = buildTeam([
      { overallPickNumber: 1, playerPickedName: "Short", cssClass: "QB" },
    ]);
    document.body.appendChild(element);

    const rendered = element.shadowRoot.querySelector("tbody tr b");
    expect(rendered.textContent).toBe("Short");
  });

  it("does not mutate the original team.picks array", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    const originalPicks = [
      {
        overallPickNumber: 1,
        playerPickedName: "Reallylongname, Somebody",
        cssClass: "QB",
      },
    ];
    element.team = buildTeam(originalPicks);
    document.body.appendChild(element);

    expect(originalPicks[0].playerPickedName).toBe("Reallylongname, Somebody");
    expect(originalPicks.length).toBe(1);
  });

  it("only shows the currency symbol when an auction cost is present", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    element.team = buildTeam([
      {
        overallPickNumber: 1,
        playerPickedName: "Priced",
        cssClass: "QB",
        auctionCost: 42,
      },
      { overallPickNumber: 2, playerPickedName: "Free", cssClass: "RB" },
    ]);
    document.body.appendChild(element);

    const rows = element.shadowRoot.querySelectorAll("tbody tr");
    expect(rows[0].textContent).toContain("£");
    expect(rows[1].textContent).not.toContain("£");
  });

  it("displays the remaining budget with no decimal places and a larger font size", () => {
    const element = createElement("c-auction-team-view", {
      is: AuctionTeamView,
    });
    element.team = buildTeam([
      { overallPickNumber: 1, playerPickedName: "A", cssClass: "QB" },
    ]);
    document.body.appendChild(element);

    const budgetFields = element.shadowRoot.querySelectorAll(
      "lightning-formatted-number"
    );
    expect(budgetFields.length).toBe(2);
    budgetFields.forEach((field) => {
      expect(field.maximumFractionDigits).toBe("0");
      expect(field.parentElement.classList).toContain("budget-remaining");
    });
  });
});
