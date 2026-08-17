import { createElement } from "lwc";
import LeagueDetails from "c/leagueDetails";
import getLeagueSetup from "@salesforce/apex/LeagueSetup.getSettings";
import saveLeagueSetup from "@salesforce/apex/LeagueSetup.saveSettings";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const SETTINGS = {
  Id: "s01",
  Year__c: "2026",
  League_Id__c: "12345",
  Generic_URL__c: "https://api.example.com",
  Instance_URL__c: "https://instance.example.com",
  API_Key__c: "secret-key",
  MFL_User_Id__c: "mfl-user",
};

describe("c-league-details", () => {
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

  async function createLeagueDetails() {
    const element = createElement("c-league-details", { is: LeagueDetails });
    document.body.appendChild(element);
    getLeagueSetup.emit(SETTINGS);
    await flushPromises();
    return element;
  }

  it("renders nothing before the league settings wire returns data", () => {
    const element = createElement("c-league-details", { is: LeagueDetails });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("lightning-card")).toBeNull();
  });

  it("hides the API key and MFL user id behind password fields by default", async () => {
    const element = await createLeagueDetails();

    const apiKeyInput = element.shadowRoot.querySelector(
      'input[class="slds-input"]'
    );
    expect(apiKeyInput.type).toBe("password");
  });

  it("reveals the API key when the visibility toggle is clicked", async () => {
    const element = await createLeagueDetails();

    const toggleButtons = element.shadowRoot.querySelectorAll("button");
    toggleButtons[0].click();
    await flushPromises();

    const apiKeyInput = element.shadowRoot.querySelectorAll("input")[0];
    expect(apiKeyInput.type).toBe("text");
  });

  it("reveals the MFL user id when its visibility toggle is clicked", async () => {
    const element = await createLeagueDetails();

    const toggleButtons = element.shadowRoot.querySelectorAll("button");
    toggleButtons[1].click();
    await flushPromises();

    const mflUserIdInput = element.shadowRoot.querySelectorAll("input")[1];
    expect(mflUserIdInput.type).toBe("text");
  });

  it("saves the settings from the form fields and shows a success toast", async () => {
    saveLeagueSetup.mockResolvedValueOnce();
    const element = await createLeagueDetails();

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();
    await flushPromises();

    expect(saveLeagueSetup).toHaveBeenCalledWith({
      settings: expect.objectContaining({
        Id: "s01",
        Year__c: "2026",
        League_Id__c: "12345",
        Generic_URL__c: "https://api.example.com",
        Instance_URL__c: "https://instance.example.com",
        API_Key__c: "secret-key",
        MFL_User_Id__c: "mfl-user",
      }),
    });
    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("success");
  });

  it("shows an error toast when saving fails", async () => {
    saveLeagueSetup.mockRejectedValueOnce({
      body: { message: "Save failed" },
    });
    const element = await createLeagueDetails();

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
