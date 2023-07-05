public class ManageDraft {

    public class Draft{
        @AuraEnabled public List<DraftRound> rounds;
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
    }

    @AuraEnabled (cacheable=true)
    public static Draft getDraft(){
        Draft draft = new Draft();
        List<Team_Owner__c> teamsInDraft = MFLManageOwners.getTeams();
        Integer teamCount = teamsInDraft.size();
        Integer roundCount = 17;

        Map<Integer, Pick__c> picksMade = getPicks();

        List<DraftRound> rounds = new List<DraftRound>();

        for(Integer round=0; round<roundCount; round++){
            Integer actualRound = round+1;
            Boolean reverse;
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
                    }else{
                        reverse = true;
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
                    String teamAndBye = picksMade.get(thePick.overallPickNumber).Player__r.NFL_Team__r.Name;
                    if(picksMade.get(thePick.overallPickNumber).Player__r.NFL_Team__r.Bye_Week__c != null){
                        teamAndBye += ' (' + picksMade.get(thePick.overallPickNumber).Player__r.NFL_Team__r.Bye_Week__c + ')';
                    }
                    thePick.playerPickedTeamAndByeWeek = teamAndBye;
                    thePick.roundNumber = Integer.valueOf(picksMade.get(thePick.overallPickNumber).Round__c);
                    thePick.playerMFLId = picksMade.get(thePick.overallPickNumber).Player__r.MFL_Id__c;
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
        List<Pick__c> picks =  [SELECT Id, Player__r.MFL_Name__c, Player__r.Position__c, Player__r.MFL_Id__c,  Player__r.NFL_Team__r.Name, Player__r.NFL_Team__r.Bye_Week__c, Round__c, Round_Pick_Number__c, Overall_Pick_Number__c FROM Pick__c];
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
        
        upsert recordsToUpsert;

        publishDraftUpdatedPlatformEvent();
    }

    @AuraEnabled
    public static void undoPick(Integer pickNumber){
        Pick__c pickToDelete = [SELECT Id FROM Pick__c WHERE Overall_Pick_Number__c = :pickNumber LIMIT 1];
        delete pickToDelete;
        publishDraftUpdatedPlatformEvent();
    }

    private static void publishDraftUpdatedPlatformEvent(){
        DraftUpdated__e event = new DraftUpdated__e();
        EventBus.publish(event);
    }

    @AuraEnabled
    public static void publishDraftMessagePlatformEvent(String message){
        Draft_Message__e event = new Draft_Message__e();
        event.Display_Message__c = message;
        EventBus.publish(event);
    }

    @AuraEnabled
    public static void submitDraft(List<RoundPick> draftJSON){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Instance_URL__c;
        url += '/' + mfl.Year__c;
        url += '/import?TYPE=draftResults&L=' + mfl.League_Id__c;
        url += '&APIKEY=' + mfl.API_Key__c;
        url += '&JSON=1';  

        String draftXML = convertJSONtoXML(draftJSON);

        HttpResponse res = MFLRetrieveData.mflPostCallout(url, draftXML);
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