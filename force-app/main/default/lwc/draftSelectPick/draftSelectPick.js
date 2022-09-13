import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import searchPlayers from '@salesforce/apex/MFLManagePlayers.searchPlayers';
import makePick from '@salesforce/apex/ManageDraft.makePick';

export default class DraftSelectPick extends LightningElement {

    @api currentRound;
    @api currentPick;
   
    @track availablePlayers;

    playersResult;

    isLoaded;
    playerSelected;
    searchTerm = null;

    get noPlayerSelected(){
        return !this.playerSelected;
    }

    @wire(searchPlayers, { searchTerm: '$searchTerm' })
    wiredPlayers(result){
        this.playersResult = result;
        if(result.data){
            this.availablePlayers = result.data;
            this.template.querySelector('lightning-input').focus();
            this.isLoaded = true;
        }
        if(result.error){
            console.log(JSON.stringify(result.error));
        }
    }

    handleSearchChange(event){
        let searchTerm = event.target.value
        if(searchTerm.length < 2 && this.searchTerm.length < 2){
            return;
        }
        this.searchTerm = searchTerm;

    }

    handleClick(event){
        let playerId = event.target.parentNode.name;
        let profileElements = this.template.querySelectorAll('c-player-profile');
        profileElements.forEach(element => {
            if(playerId === element.name){
                element.makeActive();
            }else{
                element.makeInactive();
            }
        })
        this.playerSelected = playerId;
    }

    handleConfirm(){
        console.log(JSON.stringify(this.currentPick))
        this.isLoaded = true;
        let pick = {
            Player__c: this.playerSelected,
            Round_Pick_Number__c: this.currentPick.roundPickNumber,
            Overall_Pick_Number__c: this.currentPick.overallPickNumber,
            Round__c: this.currentRound.roundNumber,
        }
        let teamId = this.currentPick.teamId
        console.log(`Pick: ${JSON.stringify(pick)} | teamId: ${teamId}`)
        makePick({pickMade: pick, teamId: teamId})
            .then(() => {
                return refreshApex(this.playersResult);
            })
            .then( () => {
                this.dispatchEvent(new CustomEvent('pickmade'));
                this.isLoaded = false;
                this.closeModal();
            })
            .catch(error => {
                console.log(JSON.stringify(error))
            })
    }

    closeModal(){
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

}