import { LightningElement, track, wire, api } from 'lwc';
import { loadScript } from "lightning/platformResourceLoader";
import cometd from "@salesforce/resourceUrl/cometd";
import getSessionId from '@salesforce/apex/CometdController.getSessionId';
import getStoredSessionId from '@salesforce/apex/CometdController.getStoredSessionId';

export default class CometD extends LightningElement {
    @api channel;

    libInitialized = false;
    @track sessionId;
    @track error;

    @wire(getSessionId)
    wiredSessionId(result) {
        if (result.data) {
            this.sessionId = result.data;
            this.error = undefined;
            loadScript(this, cometd)
                .then(() => {
                    this.initCometd()
                })
                .catch(error => {
                    console.log(error);
                })

        } else if (result.error) {
            this.error = result.error;
            this.sessionId = undefined;
            console.log(result.error);
        } else {
            getStoredSessionId()
                .then( result => {
                    this.sessionId = result;
                    loadScript(this, cometd)
                        .then(() => {
                            this.initCometd()
                        })
                        .catch(error => {
                            console.log(error);
                        })
                })
                
        }
    }

    initCometd() {
        if (this.libInitialized) {
            return;
        }
        this.libInitialized = true;
        var lwcThisContext = this;
        var cometdlib = new window.org.cometd.CometD();
        cometdlib.configure({
            url: window.location.protocol + '//' + window.location.hostname + '/cometd/54.0/',
            requestHeaders: { Authorization: 'OAuth ' + this.sessionId},
            appendMessageTypeToURL : false,
            logLevel: 'debug'
        });
        cometdlib.websocketEnabled = false;
        cometdlib.handshake(function(status) {
            // console.log('Channel Name ', lwcThisContext.channel);
            if (status.successful) {
                
                cometdlib.subscribe('/event/'+ lwcThisContext.channel, function(message){
                    const selectedEvent = new CustomEvent('message', { detail: message });
                    lwcThisContext.dispatchEvent(selectedEvent);
                });
            } else {
                console.error('Error in handshaking: ' + JSON.stringify(status));
            }
        });
    }
}