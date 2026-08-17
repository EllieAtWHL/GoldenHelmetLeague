import { createElement } from "lwc";
import CometD from "c/cometD";
import { loadScript } from "lightning/platformResourceLoader";
import getSessionId from "@salesforce/apex/CometdController.getSessionId";
import getStoredSessionId from "@salesforce/apex/CometdController.getStoredSessionId";

// eslint-disable-next-line @lwc/lwc/no-async-operation -- test-only helper to flush pending promise chains, not app runtime code
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

function createCometD() {
  const element = createElement("c-comet-d", { is: CometD });
  element.channel = "TestChannel";
  document.body.appendChild(element);
  return element;
}

function mockCometdLib() {
  const cometdInstance = {
    configure: jest.fn(),
    handshake: jest.fn(),
    subscribe: jest.fn(),
    websocketEnabled: true,
  };
  window.org = { cometd: { CometD: jest.fn(() => cometdInstance) } };
  return cometdInstance;
}

describe("c-comet-d", () => {
  let consoleLogSpy;
  let consoleErrorSpy;

  beforeEach(() => {
    consoleLogSpy = jest.spyOn(console, "log").mockImplementation();
    consoleErrorSpy = jest.spyOn(console, "error").mockImplementation();
    getStoredSessionId.mockResolvedValue("stored-session-default");
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    delete window.org;
  });

  it("loads the cometd script and initializes it when the wire returns session data", async () => {
    mockCometdLib();
    createCometD();

    getSessionId.emit("session-123");
    await flushPromises();

    expect(loadScript).toHaveBeenCalledWith(
      expect.anything(),
      expect.stringContaining("cometd")
    );
    expect(window.org.cometd.CometD).toHaveBeenCalledTimes(1);
  });

  it("does not attempt to load the script when the wire returns an error", async () => {
    createCometD();
    // The wire adapter emits an initial {data: undefined, error: undefined}
    // state on connect (matching real @wire behavior), which resolves
    // getStoredSessionId() and calls loadScript over a couple of microtask
    // hops; let that fully settle so this test only measures the effect of
    // the explicit error emit below.
    await flushPromises();
    await flushPromises();
    loadScript.mockClear();

    getSessionId.error({ message: "boom" });
    await flushPromises();

    expect(loadScript).not.toHaveBeenCalled();
    expect(consoleLogSpy).toHaveBeenCalledWith(
      expect.objectContaining({ body: { message: "boom" } })
    );
  });

  it("falls back to the stored session id when the wire has neither data nor error", async () => {
    mockCometdLib();
    getStoredSessionId.mockResolvedValueOnce("stored-session-456");
    // The wire's initial connect-time state (data: undefined, error:
    // undefined) already represents "neither data nor error" -- no
    // explicit emit needed to reach that branch.
    createCometD();

    await flushPromises();
    await flushPromises();

    expect(getStoredSessionId).toHaveBeenCalledTimes(1);
    expect(loadScript).toHaveBeenCalledWith(
      expect.anything(),
      expect.stringContaining("cometd")
    );
  });

  it("subscribes to the channel and dispatches a message event on successful handshake", async () => {
    const cometdInstance = mockCometdLib();
    const element = createCometD();
    const messageHandler = jest.fn();
    element.addEventListener("message", messageHandler);

    getSessionId.emit("session-123");
    await flushPromises();

    const handshakeCallback = cometdInstance.handshake.mock.calls[0][0];
    handshakeCallback({ successful: true });

    expect(cometdInstance.subscribe).toHaveBeenCalledWith(
      "/event/TestChannel",
      expect.any(Function)
    );

    const subscribeCallback = cometdInstance.subscribe.mock.calls[0][1];
    subscribeCallback({ someData: "payload" });

    expect(messageHandler).toHaveBeenCalledTimes(1);
    expect(messageHandler.mock.calls[0][0].detail).toEqual({
      someData: "payload",
    });
  });

  it("logs an error when the handshake is unsuccessful", async () => {
    const cometdInstance = mockCometdLib();
    createCometD();

    getSessionId.emit("session-123");
    await flushPromises();

    const handshakeCallback = cometdInstance.handshake.mock.calls[0][0];
    handshakeCallback({ successful: false });

    expect(cometdInstance.subscribe).not.toHaveBeenCalled();
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      expect.stringContaining("Error in handshaking")
    );
  });

  it("only initializes cometd once even if the wire fires more than once", async () => {
    mockCometdLib();
    createCometD();

    getSessionId.emit("session-123");
    await flushPromises();
    getSessionId.emit("session-123");
    await flushPromises();

    expect(window.org.cometd.CometD).toHaveBeenCalledTimes(1);
  });
});
