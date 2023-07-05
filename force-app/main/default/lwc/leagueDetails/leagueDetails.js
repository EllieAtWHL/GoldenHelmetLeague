import { LightningElement, wire } from 'lwc';
import getLeagueSetup from '@salesforce/apex/RetrieveLeagueSetup.getSettings';

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
        console.log(JSON.stringify(this.leagueSettings));
    }
}