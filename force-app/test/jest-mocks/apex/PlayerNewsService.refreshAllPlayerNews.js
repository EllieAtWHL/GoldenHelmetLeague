const {
  createApexTestWireAdapter,
} = require("@salesforce/wire-service-jest-util");

// Shared across every test file: works for both @wire(refreshAllPlayerNews) usage
// (via .emit()) and imperative refreshAllPlayerNews() calls (it's also a plain jest.fn()).
module.exports = {
  default: createApexTestWireAdapter(jest.fn(() => Promise.resolve())),
};
