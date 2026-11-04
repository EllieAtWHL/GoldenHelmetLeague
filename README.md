# Custom Fantasy Football Draft Application

Our NFL Fantsy Football League has been running since 2013 and used [MyFantasyLeague](https://home.myfantasyleague.com/) to run it, however my husband did not like the draft system so I built a custom draft application in Excel.
As my Salesforce career grew, I took on a project to build it in Salesforce and this is my latest version of the application.

It uses MyFantasyLeague APIs to retrieve the NFL teams, all the players and the fantasy franchises and load them in to records. Then after the draft is finished you can then upload the results back into MyFantasyLeague.

There are two community pages that are used to host the draft.

The home page of the community is a publically available site that anybody can view - meaning that as well as sharing the draft board in the room, anyone who joins remotely can easily view the draft as it happens on any device.

The commissioner page is only available if you are logged into the community as a user and allows the commissioner to run the draft by selecting the players - or undoing picks if required - and uploading the draft when finished.

## Initial Set up

### Quick start: one command

With the [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) installed and logged in to your org, run this from the repo root:

```sh
scripts/setup-org.sh <your-org-alias> [username ...]
```

(or `npm run setup-org -- <your-org-alias> [username ...]`)

This does the next three steps for you, in order:

1. Installs Nebula Logger, unless it's already installed
2. Deploys this repo and runs its tests
3. Assigns the Commissioner permission set to you, plus any extra usernames you list

It's safe to re-run. If any step fails, it stops there. Then carry on from [Populate Custom Settings](#populate-custom-settings).

To do it by hand instead, follow the three steps below.

### Install Nebula Logger (do this first)

This app uses [Nebula Logger](https://github.com/jongpie/NebulaLogger) for logging, so it must be installed in the org **before** you deploy this repo. Without it, the deploy fails with `Variable does not exist: Logger`.

Install the **Unlocked Package (no namespace)** version. The managed package won't work, because this code calls `Logger` directly rather than `Nebula.Logger`.

Tested version: **v4.19.5**

- Production / Developer Edition: [Install v4.19.5](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000IzRdAAK)
- Sandbox: [Install v4.19.5](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000IzRdAAK)
- Or via the Salesforce CLI:

  ```sh
  sf package install --package 04tg7000000IzRdAAK --wait 20 --security-type AdminsOnly --target-org <your-org-alias>
  ```

Then deploy this repo (running its tests):

```sh
sf project deploy start --source-dir force-app --test-level RunLocalTests --target-org <your-org-alias>
```

The deploy grants the System Administrator profile access to the app's custom fields, so the tests can run straight away on a brand-new org. Assign the Commissioner permission set (below) to anyone else who needs access.

It also installs and activates the **Golden Helmet** theme (SLDS 2, colours and logo, with dark mode allowed), so there's nothing to set up under Themes and Branding. For the dark look, each user picks **Dark** from their profile picture -> Appearance.

### Assign permission set

Assign whomever needs it the Commissioner permission set, which should give access to everything required to set up and run the league.

To assign it to yourself (the user the CLI is logged in as):

```sh
sf org assign permset --name Commissioner --target-org <your-org-alias>
```

To assign it to other users, add `--on-behalf-of` with each user's Salesforce username:

```sh
sf org assign permset --name Commissioner --on-behalf-of <username1> --on-behalf-of <username2> --target-org <your-org-alias>
```

### Populate Custom Settings

#### MFL

- Api Key
  This can be found by logging into your MFL league, opening the HELP menu and opening the DEVELOPER'S API page
- Generic URL (can be preset)
  This will always be `https://api.myfantasyleague.com`
- Instance URL
  This can be found by visiting your league on MFL and copying the main part of the URL, it will be something like https://www47.myfantasyleague.com
- League Id
  Your league id can be found by visiting the homepage of your league, the id is after the final slash, not including the # or anything after it, if there is one
- MFL User Id
  This is found by using the login API. This will be deprecated and will dynamically get the MFL_User_Id by calling the login api in the code and setting it
- Year
  Manually set this to the year of the current league

#### Self

First, create a Connected App, then populate the custom settings as below:
[//]: # (//TODO: Explain how to create the connected app)

- Username
  Your Salesforce username
- Password
  Your Salesforce password, followed by your security token
- Client Id
  The client id from the connected app created above
- Client Secret
  The client secret from the connected app created above
- Url
  This should always be set to:
  `https://login.salesforce.com/services/oauth2/token`
- Grant Type
  This should always be set to: `password`

### Create Experience Site and build pages

Digital Experiences -> Settings
Enable Digital Experiences and Save
Sites -> New -> Build Your Own(Aura) -> Get Started
[//]: # (Note: cometd for events won't work in LWR and would require a custom loadscript. //TODO: Consider custom script for future improvemnet/development)
Name -> choose a name for your site
URL (optional) -> enter any additional url for your site
This takes a few minutes
Builder -> Select/Create a page to show the draft board -> Components -> Drag the custom component to the main content section
Select/Create a page to show the commissioner console -> Components -> Drag the custom component to the main content section

Allow CSP Trusted Sites

Publish Site

### Guest User Access

Give access to:

- Apex Classes
  - CometdController
  - LeagueSetup
  - ManageDraft
  - MFLManageOwners
- Custom Objects (All Fields)
  - NFL Teams
  - Picks
  - Players
  - Team Owners

Create sharing rules to give access to all records for:

- NFL Teams
- Players
- Team Owners

## Draft Setup

Coming soon...
