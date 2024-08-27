import { LightningElement, wire } from 'lwc';
import {
    subscribe,
    APPLICATION_SCOPE,
    MessageContext,
} from 'lightning/messageService';
import draftMessage from '@salesforce/messageChannel/DraftMessage__c';

export default class WiggleReminder extends LightningElement {

    currentRound;
    currentPick;

    @wire(MessageContext)
    messageContext; 
    
    connectedCallback() {
        this.subscribeToMessageChannel();
    }
    
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                draftMessage,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    handleMessage(message){
        if(message.type === 'checkWiggle'){
            this.currentRound = message.detail.roundNumber;
            this.currentPick = message.detail.pickNumber;
        }
    }

    get showWiggle(){
        return (
            this.currentRound % 2 == 0
            &&
            this.currentPick == 1
        );
    }
}