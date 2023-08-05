import { LightningElement, api } from 'lwc';

export default class SnakeBoard extends LightningElement {
    @api teams;
    @api draft;
}