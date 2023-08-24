import { LightningElement, api } from 'lwc';

export default class AuctionTeamView extends LightningElement {
    @api team;

    get teamPicks(){
        let tempPicks = JSON.parse(JSON.stringify(this.team.picks));
        tempPicks.forEach( pick => {
            if(pick.playerPickedName.length > 15) {
                let tempName = pick.playerPickedName.split(',',1)[0];
                pick.playerPickedName = tempName;
            }
        })
        while(tempPicks.length < 17){
            tempPicks.push({cssClass: 'pick-made'});
        }
        
        return tempPicks;
    }
}