import { createElement } from "lwc";
import DraftMessages from "c/draftMessages";
import getDraftSettings from "@salesforce/apex/LeagueSetup.getDraftSettings";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

function sendCometdMessage(element, payload) {
  element.shadowRoot
    .querySelector("c-comet-d")
    .dispatchEvent(new CustomEvent("message", { detail: { data: payload } }));
}

describe("c-draft-messages", () => {
  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date(2026, 7, 17, 12, 0, 0));
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("shows the welcome message by default", () => {
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    expect(element.shadowRoot.textContent).toContain("Welcome to the");
    expect(element.shadowRoot.textContent).toContain("Golden Helmet Draft");
  });

  it("does not start a countdown when the countdown is not enabled", async () => {
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    getDraftSettings.emit({
      Enable_Countdown__c: false,
      Draft_Start_Date__c: new Date(2026, 7, 18).toISOString(),
    });
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Welcome to the");
  });

  it("counts down to the draft start time when the countdown is enabled", async () => {
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    getDraftSettings.emit({
      Enable_Countdown__c: true,
      Draft_Start_Date__c: new Date(2026, 7, 18, 12, 0, 1).toISOString(),
    });
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("begins in");

    jest.advanceTimersByTime(1000);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("1d 0h 0m 0s");
  });

  it("shows the message and css class from a received cometd message", async () => {
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    sendCometdMessage(element, {
      payload: { Display_Message__c: "It's your pick!", CSS_Class__c: "QB" },
    });
    await flushPromises();

    const layout = element.shadowRoot.querySelector("lightning-layout");
    expect(element.shadowRoot.textContent).toContain("It's your pick!");
    expect(layout.className).toContain("bidding QB");
  });

  it("splits a message on the </br> marker into two lines", async () => {
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    sendCometdMessage(element, {
      payload: { Display_Message__c: "Round 1</br>Pick 3" },
    });
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Round 1");
    expect(element.shadowRoot.textContent).toContain("Pick 3");
  });

  it("applies the pick class when the message is THE PICK IS IN", async () => {
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    sendCometdMessage(element, {
      payload: { Display_Message__c: "THE PICK IS IN" },
    });
    await flushPromises();

    const layout = element.shadowRoot.querySelector("lightning-layout");
    expect(layout.className).toContain("pick");
  });

  it("clears the countdown interval when the component disconnects", async () => {
    const clearIntervalSpy = jest.spyOn(global, "clearInterval");
    const element = createElement("c-draft-messages", { is: DraftMessages });
    document.body.appendChild(element);

    getDraftSettings.emit({
      Enable_Countdown__c: true,
      Draft_Start_Date__c: new Date(2026, 7, 18).toISOString(),
    });
    await flushPromises();

    document.body.removeChild(element);

    expect(clearIntervalSpy).toHaveBeenCalled();
  });
});
