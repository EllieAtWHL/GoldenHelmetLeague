import { LightningElement } from 'lwc';

const CLASSES = 'slds-align_absolute-center slds-text-align_center slds-text-heading_large slds-m-around_xx-small slds-p-vertical_xx-small full-height';
const PICK = 'THE PICK IS IN';

export default class DraftMessages extends LightningElement {
    line1 = 'Welcome to the'; 
    line2 = 'Golden Helmet Draft 2023'; //TODO: Avoid hardcoding
    position;

    messageReceived(event){
        let message = event?.detail?.data?.payload?.Display_Message__c;
        if(message.includes('</br>')){
            const textArray = message.split('</br>');
            this.line1 = textArray[0];
            this.line2 = textArray[1];
            if(textArray.length > 2){
                this.position = textArray[2];
            } else {
                this.position = undefined;
            }
            
        } else {
            this.line1 = message;
            this.line2 = undefined;
            this.position = undefined;
        }
    }

    get textClass(){
        if(this.line1 === PICK){
            return `pick ${CLASSES}`
        }
        if(this.position){
            return `bidding ${this.position} ${CLASSES}`;
        }
        return CLASSES;
    }

    get line2Class(){
        return this.position ? '' : 'clock';
    }
}