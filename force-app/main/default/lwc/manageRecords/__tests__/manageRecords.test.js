import { createElement } from "lwc";

// The real lightning/navigation stub's NavigationMixin methods live on a
// frozen prototype, so they can't be spied on directly. Mock the module
// with a version that assigns the mock as an own instance property instead
// (the standard workaround for testing NavigationMixin components).
const mockNavigate = jest.fn();
jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  return {
    NavigationMixin: Object.assign(
      (Base) =>
        class extends Base {
          constructor() {
            super();
            this[Navigate] = mockNavigate;
          }
        },
      { Navigate }
    ),
  };
});

import ManageRecords from "c/manageRecords";
import syncNFLTeams from "@salesforce/apex/MFLManageByeWeeks.manageByeWeeks";
import syncNFLPlayers from "@salesforce/apex/MFLManagePlayers.managePlayers";
import syncMFLFranchises from "@salesforce/apex/MFLManageOwners.manageOwners";
import resetDraft from "@salesforce/apex/LeagueSetup.resetDraft";
import cleanPlayers from "@salesforce/apex/MFLManagePlayers.deleteUnavailablePlayers";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

function findButtonByLabel(element, label) {
  return Array.from(
    element.shadowRoot.querySelectorAll("lightning-button")
  ).find((button) => button.label === label);
}

describe("c-manage-records", () => {
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

  function createManageRecords() {
    return createElement("c-manage-records", { is: ManageRecords });
  }

  function toastVariant() {
    const toastEvent = dispatchEventSpy.mock.calls.find(
      (call) => call[0].type === "lightning__showtoast"
    )[0];
    return toastEvent.detail.variant;
  }

  it("does not show the spinner before any action is triggered", () => {
    const element = createManageRecords();
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
  });

  it("navigates to the draft board url when Open Board is clicked", () => {
    const element = createManageRecords();
    document.body.appendChild(element);

    findButtonByLabel(element, "Open Board").click();

    expect(mockNavigate).toHaveBeenCalledWith(
      {
        type: "standard__webPage",
        attributes: {
          url: "https://goldenhelmetleague-dev-ed.develop.my.site.com/draft",
        },
      },
      false
    );
  });

  it.each([
    ["Reset", resetDraft, "Reset Successful", "Reset unsuccessful"],
    ["Clean Players", cleanPlayers, "Clean Successful", "Clean unsuccessful"],
    ["Sync Teams", syncNFLTeams, "Sync successful", "Sync unsuccessful"],
    ["Sync Players", syncNFLPlayers, "Sync successful", "Sync unsuccessful"],
    [
      "Sync Franchises",
      syncMFLFranchises,
      "Sync successful",
      "Sync unsuccessful",
    ],
  ])(
    "shows a spinner while %s runs, and a success toast when it succeeds",
    async (label, apexMethod) => {
      let resolveCall;
      apexMethod.mockImplementationOnce(
        () => new Promise((resolve) => (resolveCall = resolve))
      );
      const element = createManageRecords();
      document.body.appendChild(element);

      findButtonByLabel(element, label).click();
      await flushPromises();

      expect(
        element.shadowRoot.querySelector("lightning-spinner")
      ).not.toBeNull();

      resolveCall();
      await flushPromises();
      await flushPromises();

      expect(element.shadowRoot.querySelector("lightning-spinner")).toBeNull();
      expect(toastVariant()).toBe("success");
    }
  );

  it("shows an error toast when Reset fails", async () => {
    resetDraft.mockRejectedValueOnce({ body: { message: "boom" } });
    const element = createManageRecords();
    document.body.appendChild(element);

    findButtonByLabel(element, "Reset").click();
    await flushPromises();
    await flushPromises();

    expect(toastVariant()).toBe("error");
  });
});
