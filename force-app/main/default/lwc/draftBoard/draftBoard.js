import { LightningElement, api } from 'lwc';

const SNAKE = 'snake';
const AUCTION = 'auction';

export default class DraftBoard extends LightningElement {

    @api teams;
    @api draft;

    get isSnake(){
        return this.draft?.draftType === SNAKE;
    }

    get isAuction(){
        return this.draft?.draftType === AUCTION;
    }

    get countdownEnabled(){
        if(this.draft?.countdownEnabled && this.draft.draftStartTime){
            const startTime = new Date(this.draft.draftStartTime).getTime();
            const now = Date.now();
            return startTime > now;
        }
        return false;
    }

    get draftStartTime(){
        return this.draft?.draftStartTime;
    }

    get auctionDraft(){
        let tempDraft = {};
        tempDraft.auctionBudget = this.draft?.auctionBudget;
        tempDraft.teams = JSON.parse(JSON.stringify(this.teams));
        tempDraft.teams.forEach( team => {
            team.picks = [];
            let teamPicks = this.findAllPicks(team);
            if(teamPicks.length > 0) team.picks = teamPicks;
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