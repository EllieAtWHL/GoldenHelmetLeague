import { createElement } from "lwc";
import DraftBoard from "c/draftBoard";

const TEAMS = [{ Id: "team1" }, { Id: "team2" }];

function createDraftBoard(draftType) {
  const element = createElement("c-draft-board", { is: DraftBoard });
  element.teams = TEAMS;
  element.draft = {
    draftType,
    auctionBudget: 200,
    rounds: [
      {
        picks: [
          {
            teamOwner: "team1",
            overallPickNumber: 1,
            playerPickedName: "Player One",
          },
          {
            teamOwner: "team2",
            overallPickNumber: 2,
            playerPickedName: "Player Two",
          },
          {
            teamOwner: "team1",
            overallPickNumber: 3,
            playerPickedName: "Player Three",
          },
        ],
      },
    ],
  };
  document.body.appendChild(element);
  return element;
}

describe("c-draft-board", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the auction board and buckets picks per team for an auction draft", () => {
    const element = createDraftBoard("auction");

    expect(element.shadowRoot.querySelector("c-auction-board")).not.toBeNull();
    expect(element.shadowRoot.querySelector("c-snake-board")).toBeNull();

    const auctionBoard = element.shadowRoot.querySelector("c-auction-board");
    expect(auctionBoard.draft.auctionBudget).toBe(200);
    expect(auctionBoard.draft.teams[0].picks).toHaveLength(2);
    expect(auctionBoard.draft.teams[1].picks).toHaveLength(1);
  });

  it("does not mutate the original teams array when building the auction draft", () => {
    createDraftBoard("auction");

    expect(TEAMS[0].picks).toBeUndefined();
  });

  it("renders the snake board, passing teams and draft straight through, for a snake draft", () => {
    const element = createDraftBoard("snake");

    expect(element.shadowRoot.querySelector("c-snake-board")).not.toBeNull();
    expect(element.shadowRoot.querySelector("c-auction-board")).toBeNull();

    const snakeBoard = element.shadowRoot.querySelector("c-snake-board");
    expect(snakeBoard.teams).toEqual(TEAMS);
    expect(snakeBoard.draft).toEqual(element.draft);
  });

  it("renders neither board when the draft type is unrecognized", () => {
    const element = createDraftBoard("unknown");

    expect(element.shadowRoot.querySelector("c-auction-board")).toBeNull();
    expect(element.shadowRoot.querySelector("c-snake-board")).toBeNull();
  });
});
