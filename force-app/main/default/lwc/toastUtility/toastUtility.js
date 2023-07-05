import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export function showToast(title, message, variant) {
    let mode;
    if(variant==='error'){
        mode = 'sticky';
    }
    const event = new ShowToastEvent({
        title : title,
        message: message,
        variant: variant,
        mode: mode
    });
    dispatchEvent(event);
}