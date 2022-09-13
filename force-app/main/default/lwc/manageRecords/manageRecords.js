import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncNFLTeams from '@salesforce/apex/MFLManageByeWeeks.manageByeWeeks';
import syncNFLPlayers from '@salesforce/apex/MFLManagePlayers.managePlayers';
import syncMFLFranchises from '@salesforce/apex/MFLManageOwners.manageOwners';

export default class ManageRecords extends NavigationMixin(LightningElement) {

    isProcessing;

    openBoard(){
        this.navigateToPage('https://goldenhelmet2-dev-ed.my.site.com/draft/s/'); //TODO Don't hardcode these
    }

    openControls(){
        //https://goldenhelmet2-dev-ed.my.salesforce.com/servlet/networks/switch?networkId=0DB8d0000004E6b&
        this.navigateToPage('https://goldenhelmet2-dev-ed.my.site.com/draft/s/commissioner'); //TODO: This doesn't work as it doesn't log the user in properly
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
                this.showToast('Sync successful', null, 'success');
            })
            .catch( error => {
                this.showToast('Sync unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }
    syncPlayers(){
        this.isProcessing = true;
        syncNFLPlayers()
            .then( () => {
                this.showToast('Sync successful', null, 'success');
            })
            .catch( error => {
                this.showToast('Sync unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }
    syncFranchises(){
        this.isProcessing = true;
        syncMFLFranchises()
            .then( () => {
                this.showToast('Sync successful', null, 'success');
            })
            .catch( error => {
                this.showToast('Sync unsuccessful', error.body.message, 'error');
            })
            .finally( () => {
                this.isProcessing = false;
            })
    }

    showToast(title, message, variant ) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

}