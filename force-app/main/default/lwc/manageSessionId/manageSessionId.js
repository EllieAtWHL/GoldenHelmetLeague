import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { showToast } from 'c/toastUtility';
import getCurrentSessionId from '@salesforce/apex/CometdController.getSessionId';
import getStoredSessionId from'@salesforce/apex/CometdController.getStoredSessionId';
import setStoredSessionId from'@salesforce/apex/CometdController.setStoredSessionId';

export default class ManageSessionId extends LightningElement {

    currentSession;
    storedSession;
    currentSessionId;
    storedSessionId;

    @wire(getCurrentSessionId)
    currentSessionWire(result){
        this.currentSession = result;
        this.currentSessionId = result.data;
    }

    @wire(getStoredSessionId)
    storedSessionWire(result){
        this.storedSession = result;
        this.storedSessionId = result.data;
    }

    get sessionIdMismatch(){
        return this.currentSessionId != this.storedSessionId;
    }

    refreshStoredSessionId(){
        setStoredSessionId()
            .then( () => {
                return refreshApex(this.currentSession);
            })
            .then( () => {
                return refreshApex(this.storedSession);
            })
            .then( () => {
                showToast('Session Id updated successfully', null, 'success');
            })
            .catch( error => {
                showToast('Update unsuccessful', error.body?.message, 'error');
                console.log(JSON.stringify(error));
            })
    }
}