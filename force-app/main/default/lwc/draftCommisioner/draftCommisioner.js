import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { showToast } from 'c/toastUtility';
import getTeams from '@salesforce/apex/MFLManageOwners.getTeams';
import getDraft from '@salesforce/apex/ManageDraft.getDraft';
import undoPick from '@salesforce/apex/ManageDraft.undoPick';
import submitDraft from '@salesforce/apex/ManageDraft.submitDraft';
import sendMessage from '@salesforce/apex/ManageDraft.publishDraftMessagePlatformEvent';

export default class DraftCommisioner extends LightningElement {

    @track teams;
    @track draft;

    currentPickNumber;
    currentRoundNumber;
    showSelectionScreen;
    draftResult;
    draftOrder;

    draftStarted;
    loading;

    @wire(getTeams)
    wiredTeams(result){
        if(result.data){
            this.teams = result.data;
            let order = [];
            this.teams.forEach(team => {
                order.push({
                    Id: team.Id,
                    Owner: team.Name__c,
                    Team: team.Team_Name__c,
                    imageURL: team.Icon_URL__c,
                    franchiseId: team.Franchise_Id__c
                });
            })
            this.draftOrder = order;
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
                round.picks.forEach((pick) => {
                    if(!this.currentPickNumber && !pick.playerPickedName){
                        this.currentPickNumber = pick.roundPickNumber;
                        this.currentRoundNumber = round.roundNumber;
                        this.draftStarted = (this.currentPickNumber !== 1 || this.currentRoundNumber !== 1);
                    }
                })          
                if(round.reverse){
                    round.picks.reverse();
                }
                round.picks.forEach((pick, index) => {
                    pick.teamId = this.draftOrder[index].Id;
                    pick.owner = this.draftOrder[index].Owner;
                    pick.team = this.draftOrder[index].Team;
                    pick.round = round.roundNumber;
                    pick.imageURL = this.draftOrder[index].imageURL;
                    pick.franchiseId = this.draftOrder[index].franchiseId;
                })
            })
            this.draft = tempDraft;
            if(this.draftStarted && this.currentPick){
                sendMessage({message: `On the clock: </br> ${this.currentPick.team}`})
            }
            this.loading = false;
        }
        if(result.error){
            showToast('Upload unsuccessful', result.error?.body?.message, 'error');
            this.loading = false;
        }
    }

    get currentRound(){
        return this.draft?.rounds[this.currentRoundNumber-1];
    }

    get currentPick(){
        let getPick = this.currentRound?.picks.filter(pick => pick.roundPickNumber === this.currentPickNumber);
        return getPick ? getPick[0] : null; 
    }

    get previousPicks(){
        let picks = [];
        let previousRounds = this.draft?.rounds.filter(round => round.roundNumber < this.currentRoundNumber);
        previousRounds?.forEach(round => {
            if(round.reverse) round.picks.reverse();
            picks = picks.concat(round.picks);
        })
        let thisRoundPicks = this.currentRound?.picks.filter(pick => pick.roundPickNumber < this.currentPickNumber);
        if (this.currentRound?.reverse) thisRoundPicks.reverse();
        picks =  thisRoundPicks ? picks.concat(thisRoundPicks) : picks;
        picks = picks ? picks.reverse() : picks;
        return picks ? picks : null;
    }

    get firstPick(){
        return (this.currentPickNumber === 1 && this.currentRoundNumber === 1);
    }

    get draftComplete(){
        return !this.currentRoundNumber || !this.currentPick;
    }

    get draftRunning(){
        return this.currentRoundNumber && this.currentPick;
    }

    startDraft(){
        this.draftStarted = true;
        sendMessage({message: `On the clock: </br> ${this.currentPick.team}`})
    }

    startPick(){
        sendMessage({message: 'THE PICK IS IN'})
        this.showSelectionScreen = true;
    }

    handleClose(){
        this.showSelectionScreen = false;
    }

    handlePickMade(){
        this.loading = true;
        let roundFinished = this.currentPickNumber % this.teams.length === 0
        if(roundFinished) {
            this.currentRoundNumber++;
            this.currentPickNumber = 1;
        }else {
            this.currentPickNumber++;
        }
        this.refreshData();
    }

    handleUndo(){
        this.loading = true;
        let pickToUndo = this.getPickToUndo();;
        undoPick({pickNumber: pickToUndo})
            .then( () => {
                if(this.currentPickNumber === 1){
                    this.currentPickNumber = 12;
                    this.currentRoundNumber--;
                } else{
                    this.currentPickNumber--;
                }
                this.refreshData();
            })
            .catch(error => {
                showToast('Undo unsuccessful', error.body.message, 'error');
                this.loading = false;
            })
    }

    getPickToUndo(){
        let roundsBefore = this.currentRoundNumber-1;
        let teamsInDraft = this.teams.length;
        let previousPick = this.currentPickNumber-1;
        let picksInPreviousRounds = roundsBefore*teamsInDraft;
        return picksInPreviousRounds + previousPick;
    }

    refreshData(){
        refreshApex(this.draftResult)
            .then( () => {
                this.loading = false;
            })
    }

    handleUpload(){
        let draftResults = this.previousPicks;

        submitDraft({draftJSON: draftResults})
            .then( () => {
                showToast('Upload successful', null, 'success');
            })
            .catch( error => {
                showToast('Upload unsuccessful', error.body?.message, 'error');
            })
    }

}