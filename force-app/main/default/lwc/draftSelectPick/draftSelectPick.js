import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { showToast } from 'c/toastUtility'; 
import getTeams from '@salesforce/apex/MFLManageOwners.getTeams';
import searchPlayers from '@salesforce/apex/MFLManagePlayers.searchPlayers';
import makePick from '@salesforce/apex/ManageDraft.makePick';
import sendMessage from '@salesforce/apex/ManageDraft.publishDraftMessagePlatformEvent';

export default class DraftSelectPick extends LightningElement {

    @api currentRound;
    @api currentPick;
    @api isSnake;
   
    @track availablePlayers;

    teamValues;
    teams;

    playersResult;

    isLoaded;
    playerSelected;
    winnerEntered;
    priceEntered;
    searchTerm = null;

    get noPlayerSelected(){
        if(this.isSnake){
            return !this.playerSelected;
        } else {
            return (!this.playerSelected || !this.winnerEntered || !this.priceEntered);
        }
    }

    get isAuction(){
        return !this.isSnake;
    }

    get winnerBudget(){
        if(this.winnerEntered){
            const winnerTeam = this.teams.find( team => {
                return team.Id === this.winnerEntered;
            });
            return winnerTeam.Remaining_Budget__c;
        }
        return null;
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

    @wire(getTeams)
    wiredTeams(result){
        this.teamResult === result;
        if(result.data){
            let values = [];
            result.data.forEach(team => {
                let value = {value: team.Id, label: team.Team_Name__c}
                values.push(value);

            })
            this.teamValues = values;
            this.teams = result.data;
        }
        if(result.error){
            console.log(JSON.stringify(result.error))
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
        if(this.isAuction){
            let playersArray = this.availablePlayers.filter( player => {
                return player.Id === playerId;
            })
            const player = playersArray[0];
            const message = `Bidding on: ${player.MFL_Name__c}</br>${player.Team__c}</br>${player.Position__c}`
            sendMessage({message: message});
        }
    }

    handleChange(event){
        let valueChanged = event.target.name;
        switch(valueChanged){
            case 'winner':
                this.winnerEntered = event.detail.value;
                break;
            case 'price':
                if(this.winnerBudget < event.detail.value){
                    event.target.validity === false;
                } else {  
                    this.priceEntered = event.detail.value;
                }
                break;
            default:
                console.log('Unexpected event')
        }
    }

    handleConfirm(){
        this.isLoaded = true;
        const teamId = this.isSnake ? this.currentPick.teamId : this.refs.winner.value;
        const pick = {
            Player__c: this.playerSelected,
            Team_Owner__c: teamId,
            Round_Pick_Number__c: this.currentPick.roundPickNumber,
            Overall_Pick_Number__c: this.currentPick.overallPickNumber,
            Round__c: this.currentRound.roundNumber,
        }
        if(this.isAuction){
            pick.Auction_Cost__c = this.refs.price.value;
        }
        makePick({pickMade: pick, teamId: teamId})
            .then(() => {
                return refreshApex(this.playersResult);
            })
            .then(() => {
                return refreshApex(this.teamResult);
            })
            .then( () => {
                this.dispatchEvent(new CustomEvent('pickmade'));
                this.isLoaded = false;
                this.closeModal();
            })
            .catch(error => {
                console.log(JSON.stringify(error))
                showToast('Unable to complete transaction', error.body.message, 'error');
            })
    }

    closeModal(){
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

}