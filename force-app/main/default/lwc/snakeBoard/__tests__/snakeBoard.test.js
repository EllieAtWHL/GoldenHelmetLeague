import { createElement } from "lwc";
import SnakeBoard from "c/snakeBoard";

const TEAMS = [
  { Team_Name__c: "Team One", Icon_URL__c: "https://example.com/one.png" },
  { Team_Name__c: "Team Two", Icon_URL__c: "https://example.com/two.png" },
];

describe("c-snake-board", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders nothing when there are no teams", () => {
    const element = createElement("c-snake-board", { is: SnakeBoard });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("table")).toBeNull();
  });

  it("renders team headers but no body rows until a draft is provided", () => {
    const element = createElement("c-snake-board", { is: SnakeBoard });
    element.teams = TEAMS;
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("table")).not.toBeNull();
    expect(element.shadowRoot.querySelectorAll("thead th img").length).toBe(2);
    expect(element.shadowRoot.querySelector("tbody")).toBeNull();
  });

  it("renders a pick-number placeholder cell for an unmade pick", () => {
    const element = createElement("c-snake-board", { is: SnakeBoard });
    element.teams = TEAMS;
    element.draft = {
      rounds: [
        {
          roundNumber: 1,
          picks: [{ overallPickNumber: 1 }],
        },
      ],
    };
    document.body.appendChild(element);

    const cell = element.shadowRoot.querySelector("tbody .pick-number");
    expect(cell).not.toBeNull();
    expect(cell.textContent.trim()).toBe("1");
    expect(element.shadowRoot.querySelector("tbody .pick-made")).toBeNull();
  });

  it("renders the player name and cssClass for a made pick", () => {
    const element = createElement("c-snake-board", { is: SnakeBoard });
    element.teams = TEAMS;
    element.draft = {
      rounds: [
        {
          roundNumber: 1,
          picks: [
            {
              overallPickNumber: 1,
              playerPickedName: "Sample Player",
              playerPickedTeamAndByeWeek: "SF (Bye 9)",
              cssClass: "QB",
            },
          ],
        },
      ],
    };
    document.body.appendChild(element);

    const cell = element.shadowRoot.querySelector("tbody td.QB");
    expect(cell).not.toBeNull();
    expect(cell.textContent).toContain("Sample Player");
    expect(cell.textContent).toContain("SF (Bye 9)");
  });
});
