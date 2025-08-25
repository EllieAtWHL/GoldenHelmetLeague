import { LightningElement, track, wire } from 'lwc';
import { showToast } from 'c/toastUtility'; 
import getDraftSetup from '@salesforce/apex/LeagueSetup.getDraftSettings';
import saveDraftSetup from '@salesforce/apex/LeagueSetup.saveDraftSettings';

const SNAKE = 'snake';
const AUCTION = 'auction';
const DRAFT_TYPE_OPTIONS = [
    { label: 'Snake', value: SNAKE},
    { label: 'Auction', value: AUCTION}
]
const RANKING_OPTIONS = [
    { label: 'ADP', value: 'ADP'},
    { label: 'Fantasy Sharks', value: 'Fantasy Sharks'}
]

export default class DraftSettings extends LightningElement {

    @track draftSettings;
    error;
    saving;

    @wire(getDraftSetup)
    wiredDraftSettings(result){
        if(result.data){
            this.draftSettings = JSON.parse(JSON.stringify(result.data));
        } else {
            this.error = true;
            console.log(JSON.stringify(result));
        }
    }

    get draftTypeOptions(){
        return DRAFT_TYPE_OPTIONS;
    }

    get rankingOptions(){
        return RANKING_OPTIONS;
    }

    get isAuction(){
        return this.draftSettings.Draft_Type__c === AUCTION;
    }

    get isSnake(){
        return this.draftSettings.Draft_Type__c === SNAKE;
    }

    handleChange(event){
        this.draftSettings[event.target.name] = event.target.value;
    }

    handleSave(){
        this.saving = true;
        let newDraftSettings = {};
        newDraftSettings.Id = this.draftSettings.Id;
        newDraftSettings.Draft_Type__c = this.refs.drafttype.value;
        newDraftSettings.Ranking_Option__c = this.refs.rankingoption.value;
        newDraftSettings.Auction_Budget__c = this.refs.budget ? this.refs.budget.value : null;
        newDraftSettings.Number_of_Rounds__c = this.refs.rounds ? this.refs.rounds.value : null;
        newDraftSettings.Third_Round_Reversal__c = this.refs.reverse ? this.refs.reverse.checked : false;
        newDraftSettings.Draft_Start_Date__c = this.refs.draftstart ? this.refs.draftstart.value : null;
        newDraftSettings.Enable_Countdown__c = this.refs.countdown ? this.refs.countdown.checked : false;
        saveDraftSetup({settings: newDraftSettings})
            .then( () => {
                this.saving = false;
                showToast('Success!', 'Settings Updated', 'success');
            })
            .catch((error)=>{ 
                this.saving = false;
                this.error = true;
                showToast('Unable to update settings', error.body.message, 'error');
            })
    }
}