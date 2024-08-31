import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { showToast } from 'c/toastUtility';
import syncNFLTeams from '@salesforce/apex/MFLManageByeWeeks.manageByeWeeks';
import syncNFLPlayers from '@salesforce/apex/MFLManagePlayers.managePlayers';
import syncMFLFranchises from '@salesforce/apex/MFLManageOwners.manageOwners';
import resetDraft from '@salesforce/apex/LeagueSetup.resetDraft';
import cleanPlayers from '@salesforce/apex/MFLManagePlayers.deleteUnavailablePlayers';

export default class ManageRecords extends NavigationMixin(LightningElement) {

    isProcessing;

    openBoard(){
        this.navigateToPage('https://goldenhelmetleague-dev-ed.develop.my.site.com/draft'); //TODO Don't hardcode these
    }

    openControls(){
        //https://goldenhelmet2-dev-ed.my.salesforce.com/servlet/networks/switch?networkId=0DB8d0000004E6b&
        this.navigateToPage('https://goldenhelmet2-dev-ed.my.site.com/draft/s/commissioner'); //TODO: This doesn't work as it doesn't log the user in properly
    }

    handleReset(){
        this.isProcessing = true;
        resetDraft()
            .then( () => {
                showToast('Reset Successful', null, 'success');
            })
            .catch( error => {
                showToast('Reset unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }

    handleClean(){
        this.isProcessing = true;
        cleanPlayers()
            .then( () => {
                 showToast('Clean Successful', null, 'success');
             })
             .catch( error => {
                 showToast('Clean unsuccessful', error.body.message, 'error');
                 })
             .finally( () => {
                 this.isProcessing = false;
             })
    }

    navigateToPage(url){
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url
            }
        }, false)   
    }
    
    syncTeams(){
        this.isProcessing = true;
        syncNFLTeams()
            .then( () => {
                showToast('Sync successful', null, 'success');
            })
            .catch( error => {
                showToast('Sync unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }
    syncPlayers(){
        this.isProcessing = true;
        syncNFLPlayers()
            .then( () => {
                showToast('Sync successful', null, 'success');
            })
            .catch( error => {
                showToast('Sync unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }
    syncFranchises(){
        this.isProcessing = true;
        syncMFLFranchises()
            .then( () => {
                showToast('Sync successful', null, 'success');
            })
            .catch( error => {
                showToast('Sync unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }

}