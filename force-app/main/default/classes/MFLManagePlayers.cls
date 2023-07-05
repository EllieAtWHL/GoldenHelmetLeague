public with sharing class MFLManagePlayers {
    private Class PlayersResponse{
        Players players;
    }

    private Class Players{
        List<Player> player;
    }
    private Class Player{
        String id;
        String name;
        String team;
        String position;
        String status;
    }
    private Class ADPResponse{
        ADP adp;
    }
    private Class ADP{
        List<ADP_Player> player;
    }
    private Class ADP_Player{
        String id;
        String rank;
        String averagePick;
    }
    private Class RankPlayersResponse{
        PlayerRanks player_ranks;
    }
    private Class PlayerRanks{
        List<Rank_Player> player;
    }
    private Class Rank_Player{
        String id;
        String rank;
    }

    
    @AuraEnabled
    public static void managePlayers(){
        List<Player> mflNFLPlayers = getPlayers();

        Map<String, Player__c> nflPlayers = getNFLPlayers();

        List<ADP_Player> playersADP = getADP();
        Map<String, ADP_Player> mapPlayersADP = new Map<String, ADP_Player>();
        if(!playersADP.isEmpty()){
            for(ADP_Player adpPlayer: playersADP){
                mapPlayersADP.put(adpPlayer.id, adpPlayer);
            }
        }
        
        List<Rank_Player> playerRankList = getRank();
        Map<String, Rank_Player> mapPlayersRank = new Map<String, Rank_Player>();
        for(Rank_Player playerRank: playerRankList){
            mapPlayersRank.put(playerRank.id, playerRank);
        }

        Map<String, NFL_Team__c> mapTeams = MFLManageByeWeeks.getNFLTeams();
        Set<String> positions = getPositions();
        List<Player__c> playersToUpsert = new List<Player__c>();
        
        Id freeAgentTeamId = freeAgentTeam();

        for(Player player : mflNFLPlayers){
            if(nflPlayers !=null && nflPlayers.containsKey(player.id)){
                if(playerChanged(player, nflPlayers, mapPlayersADP, mapPlayersRank, mapTeams) == true){
                    Player__c updatedPlayer = createPlayer(player, nflPlayers, mapPlayersADP, mapPlayersRank, mapTeams, freeAgentTeamId);
                    playersToUpsert.add(updatedPlayer);
                }
            } else if(positions.contains(player.position)){
                Player__c newPlayer = createPlayer(player, nflPlayers, mapPlayersADP, mapPlayersRank, mapTeams, freeAgentTeamId);
                playersToUpsert.add(newPlayer);
            }

        }
        upsert playersToUpsert;
    }

    private static Player__c createPlayer(Player player, Map<String, Player__c> nflPlayers, Map<String, ADP_Player> mapPlayersADP, Map<String, Rank_Player> mapPlayersRank, Map<String, NFL_Team__c> mapTeams, Id freeAgentTeamId){

        Decimal adpRank;
        Decimal adpAverage;
        Decimal rank;
        Id teamID;
        Id playerId;
        if(mapPlayersADP.containsKey(player.id)){
            adpRank = Decimal.valueOf(mapPlayersADP.get(player.id).rank);
            adpAverage = Decimal.valueOf(mapPlayersADP.get(player.id).averagePick);
        }else{
            adpRank = 9999;
        }
        if(mapPlayersRank.containsKey(player.id)){
            rank = Decimal.valueOf(mapPlayersRank.get(player.id).rank);
        }else{
            rank = 9999;
        }
        if(mapTeams.containsKey(player.team)){
            teamId = mapTeams.get(player.team).Id;
        } else{
            teamId = freeAgentTeamId;
        }
        if(nflPlayers.containsKey(player.id)){
            playerId = nflPlayers.get(player.id).Id;
        }
        Player__c newPlayer = new Player__c(
            Id = playerId,
            MFL_Id__c = player.id,
            MFL_Name__c = player.name,
            Position__c = player.position,
            MFL_Status__c = player.status,
            ADP_Rank__c = adpRank,
            ADP_Average__c = adpAverage,
            Experts_Rank__c = rank,
            NFL_Team__c = teamId
        );

        return newPlayer;
    }

    private static Boolean playerChanged(Player player, Map<String, Player__c> nflPlayers, Map<String, ADP_Player> mapPlayersADP, Map<String, Rank_Player> mapPlayersRank, Map<String, NFL_Team__c> mapTeams){
        //Checks ADP fields
        if(mapPlayersADP.containsKey(player.id)){
            Decimal retrievedADPRank = Decimal.valueOf(mapPlayersADP.get(player.id).rank);
            Decimal retrievedADPAverage = Decimal.valueOf(mapPlayersADP.get(player.id).averagePick);
            Decimal storedADPRank = nflPlayers.get(player.id).ADP_Rank__c;
            Decimal storedADPAverage = nflPlayers.get(player.id).ADP_Average__c;

            if(retrievedADPAverage != storedADPAverage || retrievedADPRank != storedADPRank){
                return true;
            }
        }
        //Checks Rank field
        if(mapPlayersRank.containsKey(player.id)){
            Decimal retrievedRank = Decimal.valueOf(mapPlayersRank.get(player.id).rank);
            Decimal storedRank = nflPlayers.get(player.id).Experts_Rank__c;

            if(retrievedRank != storedRank){
                return true;
            }
        }
        //Checks team
        String retrievedTeam = player.team;
        String storedTeam = nflPlayers.get(player.id).NFL_Team__r.Name;
        if(retrievedTeam != storedTeam){
            return true;
        }
        //Checks position
        if(player.position != nflPlayers.get(player.id).Position__c){
            return true;
        }
        return false;
    }

    private static List<Player> getPlayers(){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Instance_URL__c;
        url += '/' + mfl.Year__c;
        url += '/export?TYPE=players&L=' + mfl.League_Id__c;
        url += '&APIKEY=' + mfl.API_Key__c;
        url += '&DETAILS=&SINCE=&PLAYERS=&JSON=1';

        HttpResponse calloutResponse = new HttpResponse();
        try {
            calloutResponse = MFLRetrieveData.mflGetCallout(url);
        } catch(Exception e){
            system.debug(e.getMessage());
            throw e;
        }

        PlayersResponse playerResponse = (PlayersResponse) JSON.deserialize(calloutResponse.getBody(), PlayersResponse.class);
  
        return playerResponse.players.player;
    }

    private static Map<String, Player__c> getNFLPlayers(){

        List<Player__c> players = [SELECT Id, MFL_Id__c, MFL_Name__c, NFL_Team__c, NFL_Team__r.Name, Position__c, MFL_Status__c, ADP_Average__c, ADP_Rank__c, Experts_Rank__c FROM Player__c WITH USER_MODE ORDER BY ADP_Rank__c];

        Map<String, Player__c> mapPlayers = new Map<String, Player__c>();

        for(Player__c player : players){
            mapPlayers.put(player.MFL_Id__c, player);
        }

        return mapPlayers;
    }

    private static Set<String> getPositions(){
        Set<String> positions = new Set<String>();

        Schema.DescribeFieldResult positionField = Player__c.Position__c.getDescribe(); 
        List<Schema.PicklistEntry> positionValues = positionField.getPicklistValues();
        for(Schema.PicklistEntry value : positionValues){
            positions.add(value.getLabel());
        }

        return positions;
    }

    private static List<ADP_Player> getADP(){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Generic_URL__c;
        url += '/' + mfl.Year__c;
        url += '/export?TYPE=adp&PERIOD=AUG1&FCOUNT=12&IS_PPR=1&IS_KEEPER=N&IS_MOCK=0&CUTOFF=10&DETAILS=&JSON=1';

        HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);

        ADPResponse adpResponse = (ADPResponse) JSON.deserialize(calloutResponse.getBody(), ADPResponse.class);

        if(adpResponse.adp.player == null){
            return new List<ADP_Player>();
        }
        return adpResponse.adp.player;  
    }

    private static List<Rank_Player> getRank(){

        MFL__c mfl = MFL__c.getInstance();

        String url = mfl.Generic_URL__c;
        url += '/' + mfl.Year__c;
        url += '/export?TYPE=playerRanks&POS=&JSON=1';

        HttpResponse calloutResponse = MFLRetrieveData.mflGetCallout(url);

        RankPlayersResponse rankResponse = (RankPlayersResponse) JSON.deserialize(calloutResponse.getBody(), RankPlayersResponse.class);

        return rankResponse.player_ranks.player;
    }

    private static Id freeAgentTeam(){
        system.debug('calling freeAgentTeam');
        List<NFL_Team__c> fa = [SELECT Id FROM NFL_Team__c WHERE Name = 'FA' LIMIT 1];
        if(fa.isEmpty()){
            NFL_Team__c faTeam = new NFL_Team__c(
                Name = 'FA',
                Team_Name__c = 'Free Agent'
            );
            insert faTeam;
            return faTeam.Id;
        }else{
            return fa[0].Id;
        } 
    }

    @AuraEnabled (cacheable=true)
    public static List<Player__c> searchPlayers(String searchTerm){
        if(searchTerm == null){
            return [SELECT Id, MFL_Name__c, Photo_URL_Formula__c, Position__c, Team__c, MFL_Status__c FROM Player__c WHERE Team_Owner__c = NULL WITH USER_MODE ORDER BY ADP_Rank__c LIMIT 12];
        }else{
            searchTerm = '*'+searchTerm+'*';
            List<List<SObject>> soslResult = [FIND :searchTerm IN ALL FIELDS 
                                                RETURNING Player__c
                                                (Id, MFL_Name__c, Photo_URL_Formula__c, Position__c, Team__c, MFL_Status__c WHERE Team_Owner__c = NULL ORDER BY ADP_Rank__c)
                                                LIMIT 12];
            List<Player__c> playerList = ((List<Player__c>)soslResult[0]);
            return playerList;
        }
    }
}