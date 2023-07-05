# Custom Fantasy Football Draft Application

Our NFL Fantsy Football League has been running since 2013 and used [MyFantasyLeague](https://home.myfantasyleague.com/) to run it, however my husband did not like the draft system so I built a custom draft application in Excel.
As my Salesforce career grew, I took on a project to build it in Salesforce and this is my latest version of the application.

It uses MyFantasyLeague APIs to retrieve the NFL teams, all the players and the fantasy franchises and load them in to records. Then after the draft is finished you can then upload the results back into MyFantasyLeague.

There are two community pages that are used to host the draft.

The home page of the community is a publically available site that anybody can view - meaning that as well as sharing the draft board in the room, anyone who joins remotely can easily view the draft as it happens on any device.

The commissioner page is only available if you are logged into the community as a user and allows the commissioner to run the draft by selecting the players - or undoing picks if required - and uoploading the draft when finished.