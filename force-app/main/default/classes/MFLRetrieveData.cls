public with sharing class MFLRetrieveData {
  /**
   * Thrown when MFL's API responds with HTTP 200 but its own JSON body
   * indicates an application-level error, e.g.:
   *   {"encoding":"utf-8","version":"1.0","error":{"$t":"Invalid league ID 24312"}}
   * The exception's message is MFL's own error text, so it can be shown to
   * the end user directly instead of being guessed at by the caller.
   */
  public class MFLApiException extends Exception {
  }

  public static HttpResponse sfPostCallout(String url) {
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('POST');
    HttpResponse res = new HttpResponse();

    try {
      res = http.send(req);
      Logger.info('Calling SF API: POST method')
        .setHttpRequestDetails(req)
        .setHttpResponseDetails(res);
      Logger.saveLog();
    } catch (Exception e) {
      Logger.exception('Error making POST callout to SF', e);
      Logger.saveLog();
      throw new CalloutException(e.getMessage());
    }
    return res;
  }

  public static HttpResponse mflGetCallout(String url) {
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('GET');
    HttpResponse res = new HttpResponse();

    try {
      res = http.send(req);
      Logger.info('Calling MFL API: GET method')
        .setHttpRequestDetails(req)
        .setHttpResponseDetails(res);
      Logger.saveLog();
    } catch (Exception e) {
      Logger.exception('Error making GET callout to MFL', e);
      Logger.saveLog();
      throw new CalloutException(e.getMessage());
    }

    if (res.getStatusCode() != 200) {
      Logger.error('Error making GET callout to MFL: ' + res.getBody());
      Logger.saveLog();
      throw new CalloutException(res.getBody());
    }

    throwIfMFLErrorResponse(res.getBody());

    return res;
  }

  /**
   * MFL returns HTTP 200 even for application-level errors (invalid League
   * Id, expired API Key, etc.) - the error only shows up in the response
   * body, shaped like {"error":{"$t":"the actual message"}}. Surface that
   * exact text as an MFLApiException rather than letting callers guess at
   * the cause from a typed JSON.deserialize failing downstream.
   *
   * Deliberately does not log here - callers already catch Exception and
   * log via AuraExceptionHelper, and logging right before a throw has been
   * shown to sometimes swallow that throw (see AuraExceptionHelper's
   * ApexDoc / GHL-24), so this stays a plain, un-logged throw.
   */
  private static void throwIfMFLErrorResponse(String body) {
    Object parsed;
    try {
      parsed = JSON.deserializeUntyped(body);
    } catch (Exception e) {
      return; // Not generic JSON - let the caller's own typed deserialize surface any issue.
    }

    if (!(parsed instanceof Map<String, Object>)) {
      return;
    }

    Object errorNode = ((Map<String, Object>) parsed).get('error');
    if (!(errorNode instanceof Map<String, Object>)) {
      return;
    }

    Object errorText = ((Map<String, Object>) errorNode).get('$t');
    if (errorText instanceof String) {
      throw new MFLApiException((String) errorText);
    }
  }

  public static HttpResponse mflPostCallout(String url, String draftResults) {
    MFL__c mfl = MFL__c.getInstance();

    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setHeader('Content-Type', HttpFormBuilder.GetContentType());
    req.setHeader('Cookie', 'MFL_USER_ID=' + mfl.MFL_User_Id__c);
    req.setMethod('POST');

    String body = '';
    body += HttpFormBuilder.WriteBoundary();
    body += HttpFormBuilder.WriteBodyParameter('DATA', draftResults);
    body += HttpFormBuilder.WriteBoundary(HttpFormBuilder.EndingType.CrLf);

    Blob formBlob = EncodingUtil.base64Decode(body);

    req.setHeader('Content-Length', String.valueOf(formBlob.size()));
    req.setBodyAsBlob(formBlob);

    HttpResponse res = new HttpResponse();
    try {
      res = http.send(req);
      Logger.info('Calling MFL API: POST method')
        .setHttpRequestDetails(req)
        .setHttpResponseDetails(res);
      Logger.saveLog();
    } catch (Exception e) {
      Logger.exception('Error making POST callout to MFL', e);
      Logger.saveLog();
      throw new CalloutException(e.getMessage());
    }

    if (res.getStatusCode() != 200) {
      Logger.error('Error making POST callout to MFL: ' + res.getBody());
      Logger.saveLog();
      throw new CalloutException(res.getBody());
    }
    return res;
  }
}
