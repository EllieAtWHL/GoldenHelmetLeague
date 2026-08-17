import { createElement } from "lwc";
import DraftCommisioner from "c/draftCommisioner";
import { refreshApex } from "@salesforce/apex";
import { publish } from "lightning/messageService";
import getTeams from "@salesforce/apex/MFLManageOwners.getTeams";
import getDraft from "@salesforce/apex/ManageDraft.getDraft";
import undoPick from "@salesforce/apex/ManageDraft.undoPick";
import submitDraft from "@salesforce/apex/ManageDraft.submitDraft";
import sendMessage from "@salesforce/apex/ManageDraft.publishDraftMessagePlatformEvent";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const TEAMS = [
  {
    Id: "team1",
    Name__c: "Owner One",
    Team_Name__c: "Team One",
    Icon_URL__c: "icon1.png",
    Franchise_Id__c: "f1",
  },
  {
    Id: "team2",
    Name__c: "Owner Two",
    Team_Name__c: "Team Two",
    Icon_URL__c: "icon2.png",
    Franchise_Id__c: "f2",
  },
];

// Nothing picked yet -- the first open slot is round 1, pick 1, so
// draftStarted stays false until startDraft() is explicitly called.
function buildFreshDraft(draftType) {
  return {
    draftType,
    rounds: [
      {
        roundNumber: 1,
        reverse: false,
        picks: [
          { roundPickNumber: 1, overallPickNumber: 1, playerPickedName: null },
          { roundPickNumber: 2, overallPickNumber: 2, playerPickedName: null },
        ],
      },
      {
        roundNumber: 2,
        reverse: true,
        picks: [
          { roundPickNumber: 1, overallPickNumber: 3, playerPickedName: null },
          { roundPickNumber: 2, overallPickNumber: 4, playerPickedName: null },
        ],
      },
    ],
  };
}

// Round 1 pick 1 already made; everything else open. So the "current" pick
// after createDraft() runs is round 1, pick 2 -- draftStarted is already
// true, straight into the Pick/Undo/Upload controls.
function buildInProgressDraft(draftType) {
  const draft = buildFreshDraft(draftType);
  draft.rounds[0].picks[0].playerPickedName = "Already Picked";
  draft.rounds[0].picks[0].franchiseId = "f1";
  return draft;
}

describe("c-draft-commisioner", () => {
  beforeEach(() => {
    undoPick.mockReset().mockResolvedValue();
    submitDraft.mockReset().mockResolvedValue();
    sendMessage.mockReset().mockResolvedValue();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  async function createDraftCommisioner(
    draftType,
    draft = buildInProgressDraft(draftType)
  ) {
    const element = createElement("c-draft-commisioner", {
      is: DraftCommisioner,
    });
    document.body.appendChild(element);
    getTeams.emit(TEAMS);
    getDraft.emit(draft);
    await flushPromises();
    return element;
  }

  function findButtonByLabel(element, label) {
    return Array.from(
      element.shadowRoot.querySelectorAll("lightning-button")
    ).find((button) => button.label === label);
  }

  it("shows the round/pick indicator for a snake draft and sends the on-the-clock message", async () => {
    const element = await createDraftCommisioner("snake");

    expect(element.shadowRoot.textContent).toContain("Round 1 Pick 2");
    expect(sendMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.stringContaining("On the clock"),
      })
    );
  });

  it("shows the overall pick indicator for an auction draft and sends the nominating message", async () => {
    const element = await createDraftCommisioner("auction");

    expect(element.shadowRoot.textContent).toContain("Current Pick 2");
    expect(sendMessage).toHaveBeenCalledWith(
      expect.objectContaining({
        message: expect.stringContaining("Now nominating"),
      })
    );
  });

  it("shows Start (not Pick/Undo/Upload) for a draft that hasn't started", async () => {
    const element = await createDraftCommisioner(
      "snake",
      buildFreshDraft("snake")
    );

    expect(findButtonByLabel(element, "Start")).not.toBeUndefined();
    expect(findButtonByLabel(element, "Pick")).toBeUndefined();
  });

  it("starts the draft, switching to the Pick/Undo/Upload controls", async () => {
    const element = await createDraftCommisioner(
      "snake",
      buildFreshDraft("snake")
    );

    findButtonByLabel(element, "Start").click();
    await flushPromises();

    expect(findButtonByLabel(element, "Start")).toBeUndefined();
    expect(findButtonByLabel(element, "Pick")).not.toBeUndefined();
    expect(sendMessage).toHaveBeenCalledTimes(1);
  });

  it("shows the Pick/Undo/Upload controls immediately for a draft already in progress", async () => {
    const element = await createDraftCommisioner("snake");

    expect(findButtonByLabel(element, "Start")).toBeUndefined();
    expect(findButtonByLabel(element, "Pick")).not.toBeUndefined();
  });

  it("opens the selection screen and announces THE PICK IS IN for a snake draft", async () => {
    const element = await createDraftCommisioner("snake");

    findButtonByLabel(element, "Pick").click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("c-draft-select-pick")
    ).not.toBeNull();
    expect(sendMessage).toHaveBeenCalledWith({
      message: "THE PICK IS IN",
      cssClass: null,
    });
  });

  it("closes the selection screen on closemodal", async () => {
    const element = await createDraftCommisioner("snake");
    findButtonByLabel(element, "Pick").click();
    await flushPromises();

    element.shadowRoot
      .querySelector("c-draft-select-pick")
      .dispatchEvent(new CustomEvent("closemodal"));
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-draft-select-pick")).toBeNull();
  });

  it("advances the pick counter and publishes a wiggle-check message when a pick is made", async () => {
    const element = await createDraftCommisioner("snake");
    findButtonByLabel(element, "Pick").click();
    await flushPromises();

    element.shadowRoot
      .querySelector("c-draft-select-pick")
      .dispatchEvent(new CustomEvent("pickmade"));
    await flushPromises();

    expect(refreshApex).toHaveBeenCalledTimes(1);
    // 2 teams: pick 2 was the last pick of round 1, so this wraps to round 2 pick 1.
    const publishedPayload = publish.mock.calls[0][2];
    expect(publishedPayload).toEqual({
      type: "checkWiggle",
      detail: { roundNumber: 2, pickNumber: 1 },
    });
  });

  it("undoes the last pick, moving the counter back", async () => {
    const element = await createDraftCommisioner("snake");

    findButtonByLabel(element, "Undo").click();
    await flushPromises();

    expect(undoPick).toHaveBeenCalledWith({ pickNumber: 1 });
  });

  it("shows an error toast when undo fails", async () => {
    undoPick.mockRejectedValueOnce({ body: { message: "Undo failed" } });
    const dispatchEventSpy = jest.spyOn(window, "dispatchEvent");
    const element = await createDraftCommisioner("snake");

    findButtonByLabel(element, "Undo").click();
    await flushPromises();

    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("error");
  });

  it("uploads the previous picks and shows a success toast", async () => {
    const dispatchEventSpy = jest.spyOn(window, "dispatchEvent");
    const element = await createDraftCommisioner("snake");

    findButtonByLabel(element, "Upload").click();
    await flushPromises();

    expect(submitDraft).toHaveBeenCalledWith({
      draftJSON: expect.arrayContaining([
        expect.objectContaining({ playerPickedName: "Already Picked" }),
      ]),
    });
    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("success");
  });

  it("lists made picks in the log, most recent first", async () => {
    const element = await createDraftCommisioner("snake");

    const logEntries = element.shadowRoot.querySelectorAll(
      ".logs lightning-layout-item"
    );
    expect(logEntries.length).toBe(1);
    expect(logEntries[0].textContent).toContain("Already Picked");
  });
});
