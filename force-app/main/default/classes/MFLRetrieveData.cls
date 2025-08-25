public with sharing class MFLRetrieveData {

    public static HttpResponse sfPostCallout(String url){

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        HttpResponse res = new HttpResponse();

        try{
            res = http.send(req);
            Logger.info('Calling SF API: POST method')
                .setHttpRequestDetails(req)
                .setHttpResponseDetails(res);
            Logger.saveLog();
        } catch (Exception e){
            Logger.exception('Error making POST callout to SF', e);
            Logger.saveLog();
            throw new CalloutException(e.getMessage());
        }
        return res;

    }

    public static HttpResponse mflGetCallout(String url){

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        HttpResponse res = new HttpResponse();

        try{
            res = http.send(req);
            Logger.info('Calling MFL API: GET method')
                .setHttpRequestDetails(req)
                .setHttpResponseDetails(res);
            Logger.saveLog();
        } catch (Exception e){
            Logger.exception('Error making GET callout to MFL', e);
            Logger.saveLog();
            throw new CalloutException(e.getMessage());
        }
        
        if(res.getStatusCode() != 200){
            Logger.error('Error making GET callout to MFL: ' + res.getBody());
            Logger.saveLog();
            throw new CalloutException(res.getBody());
        }
        return res;
    }

    public static HttpResponse mflPostCallout(String url, String draftResults){

        MFL__c mfl = MFL__c.getInstance();

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setHeader('Content-Type', HttpFormBuilder.GetContentType());
        req.setHeader('Cookie', 'MFL_USER_ID='+mfl.MFL_User_Id__c);
        req.setMethod('POST');

        String body = '';
        body += HttpFormBuilder.WriteBoundary();
        body += HttpFormBuilder.WriteBodyParameter('DATA', draftResults);
        body += HttpFormBuilder.WriteBoundary(HttpFormBuilder.EndingType.CrLf);
    
        Blob formBlob = EncodingUtil.base64Decode(body);
    
        req.setHeader('Content-Length', String.valueOf(formBlob.size()));
        req.setBodyAsBlob(formBlob);

        HttpResponse res = new HttpResponse(); 
        try{
            res = http.send(req);
            Logger.info('Calling MFL API: POST method')
                .setHttpRequestDetails(req)
                .setHttpResponseDetails(res);
            Logger.saveLog();
        } catch (Exception e){
            Logger.exception('Error making POST callout to MFL', e);
            Logger.saveLog();
            throw new CalloutException(e.getMessage());
        }

        if(res.getStatusCode() != 200){
            Logger.error('Error making POST callout to MFL: ' + res.getBody());
            Logger.saveLog();
            throw new CalloutException(res.getBody());
        }
        return res;
    }

}