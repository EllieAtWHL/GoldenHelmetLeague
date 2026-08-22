import { LightningElement, api } from "lwc";

export default class MyDraftBoardPlayerCard extends LightningElement {
  @api player;
  @api valueLabel;
  @api isDrafted;

  isEditing = false;
  draftNotes = "";

  get positionClass() {
    const draftedClass = this.isDrafted ? " drafted" : "";
    return `card ${this.player?.Position__c}${draftedClass}`;
  }

  get hasValueLabel() {
    return !!this.valueLabel;
  }

  get isRookie() {
    return this.player?.MFL_Status__c === "R";
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
