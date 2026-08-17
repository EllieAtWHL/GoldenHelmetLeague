import { getCurrentYear } from "c/dateUtility";

describe("c/dateUtility", () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  it("returns the current calendar year", () => {
    jest.useFakeTimers().setSystemTime(new Date(2026, 7, 17));

    expect(getCurrentYear()).toBe(2026);
  });

  it("reflects a system time in a different year", () => {
    jest.useFakeTimers().setSystemTime(new Date(2030, 0, 1));

    expect(getCurrentYear()).toBe(2030);
  });
});
