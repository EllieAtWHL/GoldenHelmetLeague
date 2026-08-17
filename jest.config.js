const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  moduleNameMapper: {
    "^@salesforce/apex$":
      "<rootDir>/force-app/test/jest-mocks/apex/refreshApex.js",
    "^@salesforce/apex/(.+)$": "<rootDir>/force-app/test/jest-mocks/apex/$1.js",
  },
};
