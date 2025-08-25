public class MFLManageOwners {
    @TestVisible
    private Class LeagueResponse{
        @TestVisible League league;
    }

    @TestVisible
    private Class League{
        @TestVisible Franchises franchises;
    }

    @TestVisible
    private Class Franchises{
        @TestVisible List<Franchise> franchise;
    }

    @TestVisible
    private Class Franchise{
        @TestVisible String name;
        @TestVisible String owner_name;
        @TestVisible String id;
        @TestVisible String icon;
        @TestVisible Integer pickNumber;
    }

    
    @AuraEnabled
    public static void manageOwners(){

        Logger.setScenario('Managing Team Owners/Franchises');

        List<Franchise> franchises = getFranchises();
        Map<String, Team_Owner__c> owners = getOwners();
        List<Team_Owner__c> ownersToUpsert = new List<Team_Owner__c>();

        Boolean isSnakeDraft = LeagueSetup.isSnakeDraft();
        Map<String, Integer> draftOrderMap = new Map<String, Integer>();

        if(isSnakeDraft){
            String draftOrderString = ManageDraft.getDraftOrder();
            List<String> draftOrderList = draftOrderString.split(',');

            for (Integer i = 0; i < draftOrderList.size(); i++) {
                draftOrderMap.put(draftOrderList[i], i + 1);
            }
        }

        for(Franchise franchise : franchises){
            if(owners != null && owners.containsKey(franchise.id)){
                if(teamChanged(franchise, owners)){                    
                    Team_Owner__c team = new Team_Owner__c(
                        Id = owners.get(franchise.id).Id,
                        Name = franchise.name,
                        Team_Name__c = franchise.name,
                        Name__c = franchise.owner_name,
                        Franchise_Id__c = franchise.id,
                        Icon_URL__c = franchise.icon
                    );
                    if(isSnakeDraft){
                        team.Pick_Number__c = draftOrderMap.get(franchise.id);
                    }
                    ownersToUpsert.add(team);
                }
            } else{
                Team_Owner__c team = new Team_Owner__c(
                    Team_Name__c = franchise.name,
                    Name = franchise.name,
                    Name__c = franchise.owner_name,
                    Franchise_Id__c = franchise.id,
                    Icon_URL__c = franchise.icon
                );
                ownersToUpsert.add(team);
            }
        }
        upsert ownersToUpsert;
    }

    private static Boolean teamChanged(Franchise franchise, Map<String, Team_Owner__c> owners){
        if(franchise.name == owners.get(franchise.id).Team_Name__c){
            return true;
        }
        if(franchise.owner_name == owners.get(franchise.id).Name__c){
            return true;
        }
        if(franchise.icon == owners.get(franchise.id).Icon_URL__c){
            return true;
        }

        if(franchise.pickNumber != owners.get(franchise.id).Pick_Number__c){
            return true;
        }

        return false;
    }

    private static List<Franchise> getFranchises(){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Instance_URL__c;
        url += '/' + mfl.Year__c;
        url += '/export?TYPE=league&L=' + mfl.League_Id__c;
        url += '&APIKEY=' + mfl.API_Key__c;
        url += '&JSON=1';

        HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);

        LeagueResponse leagueResponse = (LeagueResponse) JSON.deserialize(calloutResponse.getBody(), LeagueResponse.class);

        try{ 
            return leagueResponse.league.franchises.franchise;
        } catch(Exception e){
            Logger.exception('Error parsing franchises from MFL response', e);
            Logger.saveLog();
            throw new AuraHandledException('Error parsing franchises from MFL response: ' + e.getMessage());
        }
        
    }

    private static Map<String, Team_Owner__c> getOwners(){
        List<Team_Owner__c> teams =     [SELECT 
                                            Id, 
                                            Name__c, 
                                            Team_Name__c, 
                                            Icon_URL__c, 
                                            Franchise_Id__c,
                                            Pick_Number__c
                                        FROM Team_Owner__c 
                                        ORDER BY Pick_Number__c];
        Map<String, Team_Owner__c> mapTeams = new Map<String, Team_Owner__c>();
        for(Team_Owner__c team : teams){
            mapTeams.put(team.Franchise_Id__c, team);
        }
        return mapTeams;
    }

    @AuraEnabled (cacheable=true)
    public static List<Team_Owner__c> getTeams(){
        try {
            return  [SELECT 
                        Id, 
                        Name__c, 
                        Team_Name__c, 
                        Icon_URL__c, 
                        Franchise_Id__c, 
                        Starting_Budget__c, 
                        Remaining_Budget__c 
                    FROM Team_Owner__c 
                    ORDER BY Pick_Number__c];
        } catch (Exception e) {
            Logger.exception('Error getting team owners', e);
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }
}