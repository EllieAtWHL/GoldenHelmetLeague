import { LightningElement } from 'lwc';

const CLASSES = 'slds-align_absolute-center slds-text-align_center slds-text-heading_large slds-m-around_xx-small slds-p-vertical_xx-small full-height';
const PICK = 'THE PICK IS IN';

export default class DraftMessages extends LightningElement {
    line1 = 'Welcome to the'; 
    line2 = 'Golden Helmet Draft 2023'; //TODO: Avoid hardcoding
    cssClass;

    messageReceived(event){
        let message = event?.detail?.data?.payload?.Display_Message__c;
        this.cssClass = event?.detail?.data?.payload?.CSS_Class__c;
        console.log(event.detail.data);
        console.log(JSON.stringify(event.detail.data));
        if(message.includes('</br>')){
            const textArray = message.split('</br>');
            this.line1 = textArray[0];
            this.line2 = textArray[1];
            
        } else {
            this.line1 = message;
            this.line2 = undefined;
        }
    }

    get textClass(){
        if(this.line1 === PICK){
            return `pick ${CLASSES}`
        }
        if(this.cssClass){
            return `bidding ${this.cssClass} ${CLASSES}`;
        }
        return CLASSES;
    }

    get line2Class(){
        return this.cssClass ? '' : 'clock';
    }
}