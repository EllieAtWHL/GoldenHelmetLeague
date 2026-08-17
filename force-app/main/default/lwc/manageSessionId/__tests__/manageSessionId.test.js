import { createElement } from "lwc";
import ManageSessionId from "c/manageSessionId";
import { refreshApex } from "@salesforce/apex";
import getCurrentSessionId from "@salesforce/apex/CometdController.getSessionId";
import getStoredSessionId from "@salesforce/apex/CometdController.getStoredSessionId";
import setStoredSessionId from "@salesforce/apex/CometdController.setStoredSessionId";

// eslint-disable-next-line @lwc/lwc/no-async-operation -- test-only helper to flush pending promise chains, not app runtime code
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

describe("c-manage-session-id", () => {
  let dispatchEventSpy;

  beforeEach(() => {
    dispatchEventSpy = jest.spyOn(window, "dispatchEvent");
    setStoredSessionId.mockResolvedValue();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createManageSessionId() {
    const element = createElement("c-manage-session-id", {
      is: ManageSessionId,
    });
    document.body.appendChild(element);
    return element;
  }

  it("shows the valid state before either wire has returned a differing id", () => {
    // Both wires start out undefined === undefined (a match), which is
    // sufficient to exercise the "valid" render branch.
    const element = createManageSessionId();

    expect(element.shadowRoot.querySelector("lightning-icon").iconName).toBe(
      "action:approval"
    );
    expect(element.shadowRoot.querySelector("lightning-button")).toBeNull();
  });

  it("shows the mismatch state with a refresh button when the session ids differ", async () => {
    const element = createManageSessionId();
    getCurrentSessionId.emit("abc123");
    getStoredSessionId.emit("xyz789");
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-icon").iconName).toBe(
      "action:close"
    );
    expect(element.shadowRoot.querySelector("lightning-button")).not.toBeNull();
  });

  it("refreshes both wires and shows a success toast when the refresh button is clicked", async () => {
    const element = createManageSessionId();
    getCurrentSessionId.emit("abc123");
    getStoredSessionId.emit("xyz789");
    await flushPromises();

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();
    await flushPromises();
    await flushPromises();

    expect(setStoredSessionId).toHaveBeenCalledTimes(1);
    expect(refreshApex).toHaveBeenCalledTimes(2);
    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("success");
  });

  it("shows an error toast when refreshing the session id fails", async () => {
    setStoredSessionId.mockRejectedValueOnce({
      body: { message: "Refresh failed" },
    });
    const element = createManageSessionId();
    getCurrentSessionId.emit("abc123");
    getStoredSessionId.emit("xyz789");
    await flushPromises();

    element.shadowRoot.querySelector("lightning-button").click();
    await flushPromises();
    await flushPromises();

    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    expect(toastEvent.detail.variant).toBe("error");
    expect(toastEvent.detail.message).toBe("Refresh failed");
  });
});
