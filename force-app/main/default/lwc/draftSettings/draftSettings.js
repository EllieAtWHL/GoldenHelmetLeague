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
        newDraftSettings.Auction_Budget__c = this.refs.budget ? this.refs.budget.value : null;
        newDraftSettings.Number_of_Rounds__c = this.refs.rounds ? this.refs.rounds.value : null;
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