import { createElement } from "lwc";
import DraftHeader from "c/draftHeader";

describe("c-draft-header", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the league logo image and the draft messages child", () => {
    const element = createElement("c-draft-header", { is: DraftHeader });
    document.body.appendChild(element);

    const img = element.shadowRoot.querySelector("img");
    expect(img.src).toContain("draftLogo");
    expect(element.shadowRoot.querySelector("c-draft-messages")).not.toBeNull();
  });
});
