import { showToast } from "c/toastUtility";

describe("c/toastUtility", () => {
  let dispatchEventSpy;

  beforeEach(() => {
    dispatchEventSpy = jest.spyOn(window, "dispatchEvent");
  });

  afterEach(() => {
    dispatchEventSpy.mockRestore();
  });

  it("dispatches a lightning__showtoast event with the given title, message and variant", () => {
    showToast("Sync successful", "All players updated", "success");

    expect(dispatchEventSpy).toHaveBeenCalledTimes(1);
    const dispatchedEvent = dispatchEventSpy.mock.calls[0][0];
    expect(dispatchedEvent.type).toBe("lightning__showtoast");
    expect(dispatchedEvent.detail).toEqual({
      title: "Sync successful",
      message: "All players updated",
      variant: "success",
      mode: undefined,
    });
  });

  it("sets mode to sticky when variant is error", () => {
    showToast("Sync unsuccessful", "Something went wrong", "error");

    const dispatchedEvent = dispatchEventSpy.mock.calls[0][0];
    expect(dispatchedEvent.detail.mode).toBe("sticky");
  });

  it("leaves mode undefined for non-error variants", () => {
    showToast("Heads up", "Just a warning", "warning");

    const dispatchedEvent = dispatchEventSpy.mock.calls[0][0];
    expect(dispatchedEvent.detail.mode).toBeUndefined();
  });
});
