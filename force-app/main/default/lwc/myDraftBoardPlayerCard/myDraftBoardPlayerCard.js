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

  get hasInjuryStatus() {
    return !!this.player?.Injury_Status__c;
  }

  get injuryBadgeVariant() {
    const status = (this.player?.Injury_Status__c || "").toLowerCase();
    const isSevere =
      status.includes("out") ||
      status.includes("ir") ||
      status.includes("suspen");
    return isSevere ? "injury-badge severe" : "injury-badge caution";
  }

  get showNewsHeadline() {
    return !!this.player?.News_Headline__c;
  }

  get hasNotes() {
    return !!this.player?.My_notes__c;
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
