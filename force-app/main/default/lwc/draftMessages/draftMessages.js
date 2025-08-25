import { LightningElement, wire } from 'lwc';
import { getCurrentYear } from 'c/dateUtility';
import getDraftSettings from '@salesforce/apex/LeagueSetup.getDraftSettings';

const CLASSES = 'slds-align_absolute-center slds-text-align_center slds-text-heading_large slds-m-around_xx-small slds-p-vertical_xx-small full-height';
const PICK = 'THE PICK IS IN';

export default class DraftMessages extends LightningElement {
    draftSettings;
    starttime;
    timeRemaining;
    intervalId;
    year = getCurrentYear();
    line1 = 'Welcome to the'; 
    line2 = `Golden Helmet Draft ${this.year}`;
    cssClass;

    @wire(getDraftSettings)
    wiredDraftSettings(result){
        console.log('Wired draft settings');
        if(result.data){
            this.draftSettings = result.data;
            if(this.showCountdown){
                this.starttime = this.draftSettings.Draft_Start_Date__c;
                this.startCountdown();
                this.line1 = `Golden Helmet Draft ${this.year} begins in...`;
            }
        } else {
            console.log('Error retrieving draft settings');
            console.log(JSON.stringify(result));
        }
    }

    disconnectedCallback(){ 
        clearInterval(this.intervalId); 
    }

    get showCountdown(){
        if(this.draftSettings?.Enable_Countdown__c && this.draftSettings?.Draft_Start_Date__c){
            const startTime = new Date(this.draftSettings.Draft_Start_Date__c).getTime();
            const now = Date.now();
            return startTime > now;
        }
        return false;
    }

    startCountdown() {
        if (!this.starttime) {
            return;
        }

        const targetTime = new Date(this.starttime).getTime();

        this.intervalId = setInterval(() => {
            const now = new Date().getTime();
            const distance = targetTime - now;

            if (distance <= 0) {
                this.timeRemaining = null;
                clearInterval(this.intervalId);
            } else {
                this.timeRemaining = {
                    days: Math.floor(distance / (1000 * 60 * 60 * 24)),
                    hours: Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)),
                    minutes: Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60)),
                    seconds: Math.floor((distance % (1000 * 60)) / 1000)
                };
                this.line2 = `${this.timeRemaining.days}d ${this.timeRemaining.hours}h ${this.timeRemaining.minutes}m ${this.timeRemaining.seconds}s`;
            }
        }, 1000);
    }

    messageReceived(event){
        
        clearInterval(this.intervalId);

        let message = event?.detail?.data?.payload?.Display_Message__c;
        this.cssClass = event?.detail?.data?.payload?.CSS_Class__c;
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