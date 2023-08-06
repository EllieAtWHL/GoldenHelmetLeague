import { LightningElement, api } from 'lwc';

const SNAKE = 'snake';
const AUCTION = 'auction';

export default class DraftBoard extends LightningElement {

    @api teams;
    @api draft;

    get isSnake(){
        return this.draft.draftType === SNAKE;
    }

    get isAuction(){
        return this.draft.draftType === AUCTION;
    }

    get auctionDraft(){
        let tempDraft = {};
        tempDraft.auctionBudget = this.draft.auctionBudget;
        tempDraft.teams = JSON.parse(JSON.stringify(this.teams));
        tempDraft.teams.forEach( team => {
            team.picks = [];
            let teamPicks = this.findAllPicks(team);
            if(teamPicks.length > 0) team.picks = teamPicks;
            if(team.Current_Budget__c === undefined) team.Current_Budget__c = team.Starting_Budget__c;
        })    
        return tempDraft;
    }

    findAllPicks(team){
        let picksFound = [];
        this.draft.rounds.forEach( round => {
            round.picks.forEach ( pick => {
                if (pick.teamOwner === team.Id) {
                    picksFound.push(pick);
                }
            })
        })
        return picksFound;
    }

}