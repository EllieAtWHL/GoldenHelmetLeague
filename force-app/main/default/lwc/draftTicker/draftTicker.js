import { LightningElement, api } from 'lwc';
import { getCurrentYear } from 'c/dateUtility';

export default class DraftTicker extends LightningElement {

    @api tickerContent;
    @api isSnake;
    year = getCurrentYear();

    get tickerContentFormatted(){
        if(!this.tickerContent.length){
            return `Welcome to the ${this.year} Golden Helmet League Draft`;
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