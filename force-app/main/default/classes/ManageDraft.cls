public class ManageDraft {

    public class Draft{
        @AuraEnabled public List<DraftRound> rounds;
        @AuraEnabled public String draftType;
        @AuraEnabled public Integer numberOfRounds;
        @AuraEnabled public Decimal auctionBudget;
    }
    public class DraftRound{
        @AuraEnabled public Boolean reverse;
        @AuraEnabled public Integer roundNumber;
        @AuraEnabled public List<RoundPick> picks;
    }
    public class RoundPick{
        @AuraEnabled public Integer overallPickNumber { get; set; }
        @AuraEnabled public Integer roundPickNumber { get; set; }
        @AuraEnabled public Integer roundNumber { get; set; }
        @AuraEnabled public Id playerId { get; set; }
        @AuraEnabled public Id teamId { get; set; }
        @AuraEnabled public String playerMFLId { get; set; }
        @AuraEnabled public String franchiseId { get; set; }
        @AuraEnabled public String playerPickedName { get; set; }
        @AuraEnabled public String playerPickedPosition { get; set; }
        @AuraEnabled public String playerPickedTeamAndByeWeek { get; set; }
        @AuraEnabled public String cssClass { get; set; }
        @AuraEnabled public Decimal auctionCost { get; set; }
        @AuraEnabled public Id teamOwner { get; set; }
        @AuraEnabled public String teamOwnerName { get; set; }
    }

    @AuraEnabled (cacheable=true)
    public static Draft getDraft(){
        Draft draft = new Draft();
        List<Team_Owner__c> teamsInDraft = MFLManageOwners.getTeams();
        Integer teamCount = teamsInDraft.size();
        Draft_Settings__c draftSettings = LeagueSetup.getDraftSettings();
        draft.draftType = draftSettings.Draft_Type__c;
        Integer roundCount = draft.draftType == 'snake' ? Integer.valueOf(draftSettings.Number_of_Rounds__c) : 17; // TODO: Is there a better way to manage this?
        draft.numberOfRounds = roundCount;
        draft.auctionBudget = draftSettings.Auction_Budget__c;

        Map<Integer, Pick__c> picksMade = getPicks();

        List<DraftRound> rounds = new List<DraftRound>();

        for(Integer round=0; round<roundCount; round++){
            Integer actualRound = round+1;
            Boolean reverse = false;
            if(draft.draftType == 'snake'){
                switch on actualRound {
                    when 1 {
                        reverse = false;
                    }
                    when 2 {
                        reverse = true;
                    }
                    when else {
                        if(math.mod((actualRound), 2) == 0){
                            reverse = false;
                        }
                    }
                }
            }
            
            DraftRound theRound = new DraftRound();
            theRound.reverse = reverse;
            theRound.roundNumber = actualRound;
            rounds.add(theRound);

            List<RoundPick> picks = new List<RoundPick>();

            for(Integer pick=0; pick<teamCount; pick++){
                Integer actualPick = pick+1;

                RoundPick thePick = new RoundPick();
                thePick.overallPickNumber = ((round*teamCount)+(actualPick));
                thePick.roundPickNumber = (actualPick);
                if(picksMade.containsKey(thePick.overallPickNumber)){
                    thePick.playerPickedName = picksMade.get(thePick.overallPickNumber).Player__r.MFL_Name__c;
                    thePick.playerPickedPosition = picksMade.get(thePick.overallPickNumber).Player__r.Position__c;
                    thePick.cssClass = 'pick-made ' + thePick.playerPickedPosition;
                    thePick.auctionCost = picksMade.get(thePick.overallPickNumber).Auction_Cost__c;
                    thePick.teamOwner = picksMade.get(thePick.overallPickNumber).Team_Owner__c;
                    thePick.teamOwnerName = picksMade.get(thePick.overallPickNumber).Team_Owner__r.Team_Name__c;

                    String teamAndBye = picksMade.get(thePick.overallPickNumber).Player__r.NFL_Team__r.Name;
                    if(picksMade.get(thePick.overallPickNumber).Player__r.NFL_Team__r.Bye_Week__c != null){
                        teamAndBye += ' (' + picksMade.get(thePick.overallPickNumber).Player__r.NFL_Team__r.Bye_Week__c + ')';
                    }
                    thePick.playerPickedTeamAndByeWeek = teamAndBye;
                    thePick.roundNumber = Integer.valueOf(picksMade.get(thePick.overallPickNumber).Round__c);
                    thePick.playerMFLId = picksMade.get(thePick.overallPickNumber).Player__r.MFL_Id__c;
                    thePick.franchiseId = picksMade.get(thePick.overallPickNumber).Team_Owner__r.Franchise_Id__c;
                }
                picks.add(thePick);
                if(actualPick == teamCount){
                    theRound.picks = picks;
                }
            }
        }

        draft.rounds = rounds;
        return draft;
    }

    private static Map<Integer, Pick__c> getPicks(){
        List<Pick__c> picks =  [SELECT 
                                    Id, 
                                    Player__r.MFL_Name__c, 
                                    Player__r.Position__c, 
                                    Player__r.MFL_Id__c,  
                                    Player__r.NFL_Team__r.Name, 
                                    Player__r.NFL_Team__r.Bye_Week__c, 
                                    Round__c, 
                                    Round_Pick_Number__c, 
                                    Overall_Pick_Number__c, 
                                    Team_Owner__c, 
                                    Team_Owner__r.Team_Name__c, 
                                    Team_Owner__r.Franchise_Id__c, 
                                    Auction_Cost__c 
                                FROM Pick__c];
        Map<Integer, Pick__c> mapPicks = new Map<Integer, Pick__c>();
        for(Pick__c pick : picks){
            mapPicks.put(Integer.valueOf(pick.Overall_Pick_Number__c), pick);
        }

        return mapPicks;
    }

    @AuraEnabled
    public static void makePick(Pick__c pickMade, Id teamId){

        List<SObject> recordsToUpsert = new List<SObject>();
        recordsToUpsert.add(pickMade);
        Player__c playerToUpdate = new Player__c(
            Id = pickMade.Player__c,
            Team_Owner__c = teamId
        );
        recordsToUpsert.add(playerToUpdate);

        if(pickMade.Auction_Cost__c != null){
            Team_Owner__c teamBudget = [SELECT 
                                            Id,
                                            Remaining_Budget__c 
                                        FROM Team_Owner__c 
                                        WHERE Id = :teamId LIMIT 1];
            if (teamBudget.Remaining_Budget__c - pickMade.Auction_Cost__c < 0){
                throw new AuraHandledException('Winner cannot afford offered price.');
            }
        }
        upsert recordsToUpsert;

        publishDraftUpdatedPlatformEvent();
    }

    @AuraEnabled
    public static void undoPick(Integer pickNumber){
        Pick__c pickToDelete =  [SELECT Id 
                                FROM Pick__c 
                                WHERE Overall_Pick_Number__c = :pickNumber 
                                LIMIT 1];
        delete pickToDelete;
        publishDraftUpdatedPlatformEvent();
    }

    private static void publishDraftUpdatedPlatformEvent(){
        DraftUpdated__e event = new DraftUpdated__e();
        EventBus.publish(event);
    }

    @AuraEnabled
    public static void publishDraftMessagePlatformEvent(String message, String cssClass){
        Draft_Message__e event = new Draft_Message__e();
        event.Display_Message__c = message;
        event.CSS_Class__c = cssClass;
        EventBus.publish(event);
    }

    @AuraEnabled
    public static void submitDraft(List<RoundPick> draftJSON){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Instance_URL__c;
        url += '/' + mfl.Year__c;
        url += '/import?TYPE=draftResults&L=' + mfl.League_Id__c;
        url += '&APIKEY=' + mfl.API_Key__c;

        String draftXML = convertJSONtoXML(draftJSON);

        system.debug(draftXML);

        HttpResponse res = MFLRetrieveData.mflPostCallout(url, draftXML);

        if(res.getStatusCode() != 200){
            throw new AuraHandledException(res.getStatus());
        }
    }

    private static string convertJSONtoXML(List<RoundPick> draft){
        String xml = '<draftResults>';
        xml += '<draftUnit>';
        for(RoundPick pick : draft){
            String round = pick.roundNumber < 10 ? '0'+String.valueOf(pick.roundNumber) : String.valueOf(pick.roundNumber);
            String pickNumber = pick.roundPickNumber  < 10 ? '0'+String.valueOf(pick.roundPickNumber) : String.valueOf(pick.roundPickNumber);
            xml += '<draftPick round="';
            xml += round + '" pick="';
            xml += pickNumber +'" franchise="';
            xml += pick.franchiseId +'" player="';
            xml += pick.playerMFLId + '"/>';
        }

        xml += '</draftUnit>';
        xml += '</draftResults>';

        return xml;
    }

}