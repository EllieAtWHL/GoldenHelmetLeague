import { LightningElement, wire } from 'lwc';
import { showToast } from 'c/toastUtility'; 
import getLeagueSetup from '@salesforce/apex/LeagueSetup.getSettings';
import saveLeagueSetup from '@salesforce/apex/LeagueSetup.saveSettings';

export default class LeagueDetails extends LightningElement {

    leagueSettings;
    error;
    saving;
    showAPIKey;
    showMFLUserId;

    @wire(getLeagueSetup)
    wiredLeagueSettings(result){
        if(result.data){
            this.leagueSettings = result.data;
        } else {
            this.error = true;
            console.log(JSON.stringify(result));
        }
    }

    get APIKeyVisibility(){
        return this.showAPIKey ? 'text' : 'password';
    }

    get MFLUserIdVisibility(){
        return this.showMFLUserId ? 'text' : 'password';
    }

    get showSpinner(){
        return !this.leagueSettings || !this.error || this.saving;
    }

    handleAPIKeyVisibility(){
        this.showAPIKey = !this.showAPIKey;
    }

    handleMFLUserIdVisibility(){
        this.showMFLUserId = !this.showMFLUserId;
    }

    handleSave(){
        this.saving = true;
        let mflSettings = {};
        mflSettings.Id = this.leagueSettings.Id;
        mflSettings.Year__c = this.refs.year.value;
        mflSettings.League_Id__c = this.refs.leagueId.value;
        mflSettings.Generic_URL__c = this.refs.genericURL.value;
        mflSettings.Instance_URL__c = this.refs.instanceURL.value;
        mflSettings.API_Key__c = this.refs.apiKey.value;
        mflSettings.MFL_User_Id__c = this.refs.mflUserId.value;
        saveLeagueSetup({settings: mflSettings})
            .then( () =>{       
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