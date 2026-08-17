import { createElement } from "lwc";
import LeagueSetup from "c/leagueSetup";

describe("c-league-setup", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("composes the league details, draft settings and manage records children", () => {
    const element = createElement("c-league-setup", { is: LeagueSetup });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("c-league-details")).not.toBeNull();
    expect(element.shadowRoot.querySelector("c-draft-settings")).not.toBeNull();
    expect(element.shadowRoot.querySelector("c-manage-records")).not.toBeNull();
  });
});
