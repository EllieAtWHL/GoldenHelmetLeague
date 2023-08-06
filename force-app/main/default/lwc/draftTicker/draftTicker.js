import { LightningElement, api } from 'lwc';

export default class DraftTicker extends LightningElement {

    @api tickerContent;

    get tickerContentFormatted(){
        if(!this.tickerContent.length){
            return `Welcome to the 2023 Golden Helmet League Draft`; //TODO: Avoid hard-coding
        }

        let content = `Recent picks: `;

        this.tickerContent.forEach(pick => {
            content += `${pick.roundNumber}.${pick.roundPickNumber} ${pick.playerPickedName} `;
        })

        return content;
    }
}