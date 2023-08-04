import { LightningElement } from 'lwc';

const CLASSES = 'slds-align_absolute-center slds-text-align_center slds-text-heading_large slds-m-around_xx-small slds-p-vertical_xx-small full-height';
const PICK = 'THE PICK IS IN';

export default class DraftMessages extends LightningElement {
    message = 'Welcome to the'; 
    clock = 'Golden Helmet Draft 2023'; //TODO: Avoid hardcoding

    messageReceived(event){
        let message = event?.detail?.data?.payload?.Display_Message__c;
        console.log(message);
        if(message.includes('</br>')){
            const textArray = message.split('</br>');
            console.log(textArray);
            this.message = textArray[0];
            this.clock = textArray[1];
        } else {
            this.message = message;
            this.clock = undefined;
        }
    }

    get textClass(){
        return this.message === PICK ? `pick ${CLASSES}` : CLASSES;
    }
}