import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getTeams from '@salesforce/apex/MFLManageOwners.getTeams';
import getDraft from '@salesforce/apex/ManageDraft.getDraft';

export default class DraftContainer extends LightningElement {

    @track teams;
    @track draft;

    draftResult;

    loading;
    @wire(getTeams)
    wiredTeams(result){
        if(result.data){
            this.teams = result.data;
        }
        if(result.error){
            console.log(JSON.stringify(result.error))
        }
    }

    @wire(getDraft)
    wiredDraft(result){
        this.draftResult = result;
        if(result.data){
            let tempDraft = JSON.parse(JSON.stringify(result.data));
            tempDraft.rounds.forEach(round => {         
                if(round.reverse){
                    round.picks.reverse();
                }
            })
            this.draft = tempDraft;
        }
        if(result.error){
            console.log(JSON.stringify(result.error))
        }
        this.loading = false;
    }

    get isMobile(){
        return FORM_FACTOR === 'Small';
    }

    get isSnake(){
        return this.draft?.draftType === 'snake';
    }

    get tickerPicks(){
        let lastTwelvePicks = [];

        if(this.draft){
            let reverseDraft = JSON.parse(JSON.stringify(this.draft));   
           
            reverseDraft = reverseDraft.rounds.reverse();            
            reverseDraft?.forEach(round => {
                if(!round.reverse) round.picks.reverse();
                round.picks.forEach(pick => {                  
                    if(pick.playerPickedName && lastTwelvePicks.length < 12) {
                        pick.roundNumber = round.roundNumber;
                        lastTwelvePicks.push(pick);
                    }
                })
            })
        }

        return lastTwelvePicks;
    }

    messageReceived(){
        this.handlePickMade();
    }

    handlePickMade(){
        refreshApex(this.draftResult)
            .then( () => {
                this.loading = false;
            })
    }
}