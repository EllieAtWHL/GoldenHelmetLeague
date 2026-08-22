import { LightningElement, api } from "lwc";

export default class MyDraftBoardPlayerCard extends LightningElement {
  @api player;
  @api valueLabel;

  isEditing = false;
  draftNotes = "";

  get positionClass() {
    return `card ${this.player?.Position__c}`;
  }

  get hasValueLabel() {
    return !!this.valueLabel;
  }

  handleEdit() {
    this.draftNotes = this.player.My_notes__c || "";
    this.isEditing = true;
  }

  handleCancel() {
    this.isEditing = false;
  }

  handleNotesChange(event) {
    this.draftNotes = event.detail.value;
  }

  handleSave() {
    this.isEditing = false;
    this.dispatchEvent(
      new CustomEvent("notessave", {
        detail: { playerId: this.player.Id, notes: this.draftNotes },
      })
    );
  }
}
