import { createElement } from "lwc";
import WiggleReminder from "c/wiggleReminder";
import { subscribe, APPLICATION_SCOPE } from "lightning/messageService";

describe("c-wiggle-reminder", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createWiggleReminder() {
    return createElement("c-wiggle-reminder", { is: WiggleReminder });
  }

  function sendMessage(payload) {
    const subscribeCallback = subscribe.mock.calls[0][2];
    subscribeCallback(payload);
  }

  it("subscribes to the draft message channel on connect", () => {
    document.body.appendChild(createWiggleReminder());

    expect(subscribe).toHaveBeenCalledTimes(1);
    expect(subscribe.mock.calls[0][3]).toEqual({
      scope: APPLICATION_SCOPE,
    });
  });

  it("does not show the wiggle reminder before any message is received", () => {
    const element = createWiggleReminder();
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector(".shake")).toBeNull();
  });

  it("shows the wiggle reminder on an even round when it is pick 1", async () => {
    const element = createWiggleReminder();
    document.body.appendChild(element);

    sendMessage({
      type: "checkWiggle",
      detail: { roundNumber: 2, pickNumber: 1 },
    });
    await Promise.resolve();

    expect(element.shadowRoot.querySelector(".shake")).not.toBeNull();
  });

  it("does not show the wiggle reminder on an odd round", async () => {
    const element = createWiggleReminder();
    document.body.appendChild(element);

    sendMessage({
      type: "checkWiggle",
      detail: { roundNumber: 3, pickNumber: 1 },
    });
    await Promise.resolve();

    expect(element.shadowRoot.querySelector(".shake")).toBeNull();
  });

  it("does not show the wiggle reminder when it is not pick 1", async () => {
    const element = createWiggleReminder();
    document.body.appendChild(element);

    sendMessage({
      type: "checkWiggle",
      detail: { roundNumber: 2, pickNumber: 5 },
    });
    await Promise.resolve();

    expect(element.shadowRoot.querySelector(".shake")).toBeNull();
  });

  it("ignores messages that are not of type checkWiggle", async () => {
    const element = createWiggleReminder();
    document.body.appendChild(element);

    sendMessage({
      type: "somethingElse",
      detail: { roundNumber: 2, pickNumber: 1 },
    });
    await Promise.resolve();

    expect(element.shadowRoot.querySelector(".shake")).toBeNull();
  });
});
