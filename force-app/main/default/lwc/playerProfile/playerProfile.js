import { LightningElement, api } from 'lwc';

export default class PlayerProfile extends LightningElement {
    @api player;

    get positionClass(){
        return `profile ${this.player.Position__c}`;
    }

    @api makeActive(){
        this.profileElement.classList.add('active');
    }

    @api makeInactive(){
        this.profileElement.classList.remove('active');
    }

    get profileElement(){
        return this.template.querySelector('lightning-layout');
    }
}