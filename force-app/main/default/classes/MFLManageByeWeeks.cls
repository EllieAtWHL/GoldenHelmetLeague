public with sharing class MFLManageByeWeeks {
    @TestVisible
    private Class ByeWeekResponse{
        @TestVisible ByeWeek nflByeWeeks;
    }
    @TestVisible
    private Class ByeWeek{
        @TestVisible List<Team> team;
    }
    @TestVisible
    private Class Team{
        @TestVisible Integer bye_week;
        @TestVisible String id;
    }

    @AuraEnabled
    public static void manageByeWeeks(){

        Logger.setScenario('Managing NFL Bye Weeks');

        List<Team> mflNFLTeams = getByeWeeks();
        Map<String, NFL_Team__c> nflTeams = getNFLTeams();
        List<NFL_Team__c> teamsToUpsert = new List<NFL_Team__c>();

        for(Team team : mflNFLTeams){
            if(nflTeams != null && nflTeams.containsKey(team.id)){
                if(nflTeams.get(team.id).Bye_Week__c != team.bye_week){
                    NFL_Team__c updatedTeam = new NFL_Team__c(
                        Id = nflTeams.get(team.id).Id,
                        Bye_Week__c = team.bye_week
                    );
                    teamsToUpsert.add(updatedTeam);
                }
            } else{
                NFL_Team__c newTeam = new NFL_Team__c(
                    Name = team.id,
                    Bye_Week__c = team.bye_week
                );
                teamsToUpsert.add(newTeam);
            }
        }

        try{
            upsert teamsToUpsert;
        } catch (Exception e){
            Logger.exception('Error upserting NFL Teams with Bye Weeks', e);
            Logger.saveLog();
            throw new AuraHandledException('Error upserting NFL Teams with Bye Weeks: ' + e.getMessage());
        }

    }

    @TestVisible
    private static List<Team> getByeWeeks(){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Generic_URL__c;
        url += '/' + mfl.Year__c;
        url += '/export?TYPE=nflByeWeeks&W=&JSON=1';

        HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);
        
        ByeWeekResponse teamResponse = (ByeWeekResponse) JSON.deserialize(calloutResponse.getBody(), ByeWeekResponse.class);

        return teamResponse.nflByeWeeks.team;
        
    }

    public static Map<String, NFL_Team__c> getNFLTeams(){
        
        List<NFL_Team__c> teams =   [SELECT 
                                        Id, 
                                        Name, 
                                        Bye_Week__c 
                                    FROM NFL_Team__c 
                                    WITH USER_MODE];

        Map<String, NFL_Team__c> mapTeams = new Map<String, NFL_Team__c>();

        for(NFL_Team__c nflTeam : teams){
            mapTeams.put(nflTeam.Name, nflTeam);
        }
        return mapTeams;
    }

}