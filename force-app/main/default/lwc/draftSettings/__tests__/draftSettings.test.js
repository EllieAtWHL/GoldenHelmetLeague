import { createElement } from "lwc";
import DraftSettings from "c/draftSettings";
import getDraftSetup from "@salesforce/apex/LeagueSetup.getDraftSettings";
import saveDraftSetup from "@salesforce/apex/LeagueSetup.saveDraftSettings";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

// Static label="..."/name="..." values aren't guaranteed to reflect as
// queryable DOM attributes for LWC custom elements -- filter on the JS
// property instead.
function findByLabel(element, tag, label) {
  return Array.from(element.shadowRoot.querySelectorAll(tag)).find(
    (el) => el.label === label
  );
}
function findByName(element, tag, name) {
  return Array.from(element.shadowRoot.querySelectorAll(tag)).find(
    (el) => el.name === name
  );
}

const AUCTION_SETTINGS = {
  Id: "a01",
  Draft_Type__c: "auction",
  Ranking_Option__c: "ADP",
  Auction_Budget__c: 200,
  Third_Round_Reversal__c: false,
  Draft_Start_Date__c: null,
  Enable_Countdown__c: false,
};

const SNAKE_SETTINGS = {
  ...AUCTION_SETTINGS,
  Draft_Type__c: "snake",
  Number_of_Rounds__c: 17,
};

describe("c-draft-settings", () => {
  let dispatchEventSpy;

  beforeEach(() => {
    dispatchEventSpy = jest.spyOn(window, "dispatchEvent");
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  async function createDraftSettings(settings) {
    const element = createElement("c-draft-settings", { is: DraftSettings });
    document.body.appendChild(element);
    getDraftSetup.emit(settings);
    await flushPromises();
    return element;
  }

  it("renders nothing before the draft settings wire returns data", () => {
    const element = createElement("c-draft-settings", { is: DraftSettings });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("lightning-card")).toBeNull();
  });

  it("shows the budget field and hides round fields for an auction draft", async () => {
    const element = await createDraftSettings(AUCTION_SETTINGS);

    expect(
      findByLabel(element, "lightning-input", "Budget")
    ).not.toBeUndefined();
    expect(
      findByLabel(element, "lightning-input", "Number of Rounds")
    ).toBeUndefined();
  });

  it("shows round and reversal fields and hides budget for a snake draft", async () => {
    const element = await createDraftSettings(SNAKE_SETTINGS);

    expect(
      findByLabel(element, "lightning-input", "Number of Rounds")
    ).not.toBeUndefined();
    expect(
      findByLabel(element, "lightning-input", "Third Round Reversal")
    ).not.toBeUndefined();
    expect(findByLabel(element, "lightning-input", "Budget")).toBeUndefined();
  });

  it("switches the visible fields when the draft type combobox changes", async () => {
    const element = await createDraftSettings(AUCTION_SETTINGS);

    const draftTypeCombobox = findByName(
      element,
      "lightning-combobox",
      "Draft_Type__c"
    );
    draftTypeCombobox.value = "snake";
    draftTypeCombobox.dispatchEvent(new CustomEvent("change"));
    await flushPromises();

    expect(
      findByLabel(element, "lightning-input", "Number of Rounds")
    ).not.toBeUndefined();
    expect(findByLabel(element, "lightning-input", "Budget")).toBeUndefined();
  });

  it("saves the auction-specific fields and shows a success toast", async () => {
    saveDraftSetup.mockResolvedValueOnce();
    const element = await createDraftSettings(AUCTION_SETTINGS);

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();
    await flushPromises();

    expect(saveDraftSetup).toHaveBeenCalledWith({
      settings: expect.objectContaining({
        Id: "a01",
        Draft_Type__c: "auction",
        Ranking_Option__c: "ADP",
        Auction_Budget__c: 200,
        Number_of_Rounds__c: null,
        Third_Round_Reversal__c: false,
      }),
    });
    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("success");
  });

  it("shows an error toast when saving fails", async () => {
    saveDraftSetup.mockRejectedValueOnce({
      body: { message: "Save failed" },
    });
    const element = await createDraftSettings(AUCTION_SETTINGS);

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();
    await flushPromises();

    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("error");
    expect(toastEvent.detail.message).toBe("Save failed");
  });
});
