public class MFLManageOwners {
    private Class LeagueResponse{
        League league;
    }

    private Class League{
        Franchises franchises;
    }

    private Class Franchises{
        List<Franchise> franchise;
    }

    private Class Franchise{
        String name;
        String owner_name;
        String id;
        String icon;
    }

    
    @AuraEnabled
    public static void manageOwners(){

        List<Franchise> franchises = getFranchises();
        Map<String, Team_Owner__c> owners = getOwners();
        List<Team_Owner__c> ownersToUpsert = new List<Team_Owner__c>();

        for(Franchise franchise : franchises){
            if(owners != null && owners.containsKey(franchise.id)){
                if(teamChanged(franchise, owners)){                    
                    Team_Owner__c team = new Team_Owner__c(
                        Id = owners.get(franchise.id).Id,
                        Team_Name__c = franchise.name,
                        Name__c = franchise.owner_name,
                        Franchise_Id__c = franchise.id,
                        Icon_URL__c = franchise.icon
                    );
                    ownersToUpsert.add(team);
                }
            } else{
                Team_Owner__c team = new Team_Owner__c(
                    Team_Name__c = franchise.name,
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

        return leagueResponse.league.franchises.franchise;

    }

    private static Map<String, Team_Owner__c> getOwners(){
        List<Team_Owner__c> teams = [SELECT Id, Name__c, Team_Name__c, Icon_URL__c, Franchise_Id__c FROM Team_Owner__c ORDER BY Pick_Number__c];
        Map<String, Team_Owner__c> mapTeams = new Map<String, Team_Owner__c>();
        for(Team_Owner__c team : teams){
            mapTeams.put(team.Franchise_Id__c, team);
        }
        return mapTeams;
    }

    @AuraEnabled (cacheable=true)
    public static List<Team_Owner__c> getTeams(){
        try {
            return [SELECT Id, Name__c, Team_Name__c, Icon_URL__c, Franchise_Id__c, Starting_Budget__c, Current_Budget__c FROM Team_Owner__c ORDER BY Pick_Number__c];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}