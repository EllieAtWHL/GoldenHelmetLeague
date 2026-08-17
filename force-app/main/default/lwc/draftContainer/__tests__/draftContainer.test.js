import { createElement } from "lwc";
import DraftContainer from "c/draftContainer";
import { refreshApex } from "@salesforce/apex";
import getTeams from "@salesforce/apex/MFLManageOwners.getTeams";
import getDraft from "@salesforce/apex/ManageDraft.getDraft";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const TEAMS = [{ Id: "team1" }, { Id: "team2" }];

function buildDraft(draftType, rounds) {
  return { draftType, rounds };
}

describe("c-draft-container", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  async function createDraftContainer() {
    const element = createElement("c-draft-container", {
      is: DraftContainer,
    });
    document.body.appendChild(element);
    getTeams.emit(TEAMS);
    getDraft.emit(buildDraft("snake", []));
    await flushPromises();
    return element;
  }

  it("passes the wired teams and draft through to the draft board", async () => {
    const element = await createDraftContainer();

    const draftBoard = element.shadowRoot.querySelector("c-draft-board");
    expect(draftBoard.teams).toEqual(TEAMS);
    expect(draftBoard.draft.draftType).toBe("snake");
  });

  it("passes is-snake through to the ticker for a snake draft", async () => {
    const element = await createDraftContainer();

    const ticker = element.shadowRoot.querySelector("c-draft-ticker");
    expect(ticker.isSnake).toBe(true);
  });

  it("builds the ticker's last-12-picks list, tagging each with its round number", async () => {
    const element = createElement("c-draft-container", {
      is: DraftContainer,
    });
    document.body.appendChild(element);
    getTeams.emit(TEAMS);
    getDraft.emit(
      buildDraft("snake", [
        {
          roundNumber: 1,
          reverse: false,
          picks: [
            { overallPickNumber: 1, playerPickedName: "First" },
            { overallPickNumber: 2, playerPickedName: "Second" },
          ],
        },
        {
          roundNumber: 2,
          reverse: true,
          picks: [
            { overallPickNumber: 3, playerPickedName: "Third" },
            { overallPickNumber: 4 },
          ],
        },
      ])
    );
    await flushPromises();

    const ticker = element.shadowRoot.querySelector("c-draft-ticker");
    const names = ticker.tickerContent.map((pick) => pick.playerPickedName);
    const roundNumbers = ticker.tickerContent.map((pick) => pick.roundNumber);
    expect(names).toEqual(["Third", "Second", "First"]);
    expect(roundNumbers).toEqual([2, 1, 1]);
  });

  it("refreshes teams and draft and clears the loading spinner when a pick is made", async () => {
    const element = await createDraftContainer();
    element.shadowRoot
      .querySelector("c-comet-d")
      .dispatchEvent(new CustomEvent("message"));
    await flushPromises();
    await flushPromises();

    expect(refreshApex).toHaveBeenCalledTimes(2);
    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });
});
