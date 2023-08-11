import { LightningElement, wire } from 'lwc';
import getCurrentSessionId from '@salesforce/apex/CometdController.getSessionId';
import getStoredSessionId from'@salesforce/apex/CometdController.getStoredSessionId';
import setStoredSessionId from'@salesforce/apex/CometdController.setStoredSessionId';

export default class ManageSessionId extends LightningElement {

    @wire(getCurrentSessionId)
    currentSessionId;

    @wire(getStoredSessionId)
    storedSessionId;

    get sessionIdMismatch(){
        return this.currentSessionId.data != this.storedSessionId.data;
    }

    refreshStoredSessionId(){
        setStoredSessionId()
            .then( () => {
                console.log('Successful')
            })
            .catch( error => {
                console.log(JSON.stringify(error));
            })
    }
}