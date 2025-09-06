public with sharing class TestDataFactory {

    public static List<Player__c> createPlayers(Integer numberOfPlayers){
        List<Player__c> players = new List<Player__c>();
        for(Integer i=0; i<numberOfPlayers; i++){
            Player__c player = new Player__c();
            players.add(player);
        }
        return players;
    }
    
    public static List<Team_Owner__c> createFranchises(Integer numberOfFranchises){
        List<Team_Owner__c> franchises = new List<Team_Owner__c>();
        for(Integer i=0; i<numberOfFranchises; i++){
            Team_Owner__c franchise = new Team_Owner__c();
            franchises.add(franchise);
        }
        return franchises;
    }

    public static  List<Pick__c> createPicks(Id playerId, Id teamId, Integer numberOfPicks){
        List<Pick__c> picks = new List<Pick__c>();
        for(Integer i=0; i<numberOfPicks; i++){
            Pick__c pick = new Pick__c();
            pick.Player__c = playerId;
            pick.Team_Owner__c = teamId;
            pick.Overall_Pick_Number__c = i+1;
            picks.add(pick);
        }
        return picks;
    }

    public static void createTestDraft(){
        List<SObject> recordsToInsert = new List<SObject>();
        Player__c player = createPlayers(1)[0];
        recordsToInsert.add(player);
        Team_Owner__c franchise = createFranchises(1)[0];
        recordsToInsert.add(franchise);
        insert recordsToInsert;

        List<Pick__c> picks = createPicks(player.Id, franchise.Id, 5);
        insert picks;
        //TODO: Make sure its different players and franchises
    }

}