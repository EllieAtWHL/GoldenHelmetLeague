import { LightningElement, api } from 'lwc';

export default class DraftTicker extends LightningElement {

    @api tickerContent;
    @api isSnake;

    get tickerContentFormatted(){
        if(!this.tickerContent.length){
            return `Welcome to the 2023 Golden Helmet League Draft`; //TODO: Avoid hard-coding
        }

        let content = `Recent picks: `;
        this.tickerContent.forEach( (pick, index, array) => {
            if(this.isSnake){
                content += `${pick.roundNumber}.${pick.roundPickNumber} ${pick.playerPickedName} `;
            } else {
                content += `${pick.playerPickedName} - £${pick.auctionCost}`;
                if(index + 1 !== array.length){
                    content += `, `;
                }
            }
        })

        return content;
    }
}