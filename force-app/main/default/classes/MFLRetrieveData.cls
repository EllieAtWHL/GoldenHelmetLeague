public with sharing class MFLRetrieveData {

    public static HttpResponse sfPostCallout(String url){

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');

        HttpResponse res = http.send(req);
        return res;

    }

    public static HttpResponse mflGetCallout(String url){

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');

        HttpResponse res = http.send(req);
        if(res.getStatusCode() != 200){
            throw new CalloutException(res.getBody());
        }
        return res;
    }

    public static HttpResponse mflPostCallout(String url, String draftResults){

        GHL__c ghl = GHL__c.getInstance();

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setHeader('Content-Type', HttpFormBuilder.GetContentType());
        req.setHeader('Cookie', 'MFL_USER_ID='+ghl.MFL_User_Id__c);
        req.setMethod('POST');

        String body = '';
        body += HttpFormBuilder.WriteBoundary();
        body += HttpFormBuilder.WriteBodyParameter('DATA', draftResults);
        body += HttpFormBuilder.WriteBoundary(HttpFormBuilder.EndingType.CrLf);
    
        Blob formBlob = EncodingUtil.base64Decode(body);
    
        req.setHeader('Content-Length', String.valueOf(formBlob.size()));
        req.setBodyAsBlob(formBlob);

        HttpResponse res = http.send(req);
        return res;
    }

}