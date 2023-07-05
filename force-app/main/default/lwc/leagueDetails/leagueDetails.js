import { LightningElement, wire } from 'lwc';
import { showToast } from 'c/toastUtility'; 
import getLeagueSetup from '@salesforce/apex/LeagueSetup.getSettings';
import saveLeagueSetup from '@salesforce/apex/LeagueSetup.saveSettings';

export default class LeagueDetails extends LightningElement {

    leagueSettings;
    showAPIKey;
    showMFLUserId;

    @wire(getLeagueSetup)
    wiredLeagueSettings(result){
        if(result.data){
            this.leagueSettings = result.data;
        } else {
            console.log(JSON.stringify(result));
        }
    }

    get APIKeyVisibility(){
        return this.showAPIKey ? 'text' : 'password';
    }

    get MFLUserIdVisibility(){
        return this.showMFLUserId ? 'text' : 'password';
    }

    handleAPIKeyVisibility(){
        this.showAPIKey = !this.showAPIKey;
    }

    handleMFLUserIdVisibility(){
        this.showMFLUserId = !this.showMFLUserId;
    }

    handleSave(){
        let mflSettings = {};
        mflSettings.Id = this.leagueSettings.Id;
        mflSettings.Year__c = this.refs.year.value;
        mflSettings.League_Id__c = this.refs.leagueId.value;
        mflSettings.Generic_URL__c = this.refs.genericURL.value;
        mflSettings.Instance_URL__c = this.refs.instanceURL.value;
        mflSettings.API_Key__c = this.refs.apiKey.value;
        mflSettings.MFL_User_Id__c = this.refs.mflUserId.value;
        console.log(JSON.stringify(mflSettings));
        saveLeagueSetup({settings: mflSettings})
            .then( () =>{           
                showToast('Success!', 'Settings Updated', 'success');
            })
            .catch((error)=>{ 
                showToast('Unable to update settings', error.body.message, 'error');
            })
    }
}