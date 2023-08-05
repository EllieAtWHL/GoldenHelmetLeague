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

    get auctionDraft(){this
        let tempAuction = JSON.parse(JSON.stringify(this.draft));
        tempAuction.teams = this.teams;
        console.log(JSON.stringify(tempAuction));
        return tempAuction;
    }

}