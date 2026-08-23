/**
 * Transport for ESPN's free, keyless site.api.espn.com /
 * sports.core.api.espn.com endpoints (see PlayerNewsService), mirroring
 * MFLRetrieveData.mflGetCallout()'s shape. Unlike MFL, ESPN's endpoints are
 * unofficial/undocumented - there's no known app-level error envelope to
 * unwrap on a 200, so this only handles transport-level failures (thrown
 * Exception, non-200 status).
 *
 * Sets an explicit User-Agent (Apex's HttpRequest sends none by default).
 * Confirmed live on 2026-08-23: ESPN's Akamai edge WAF returns 403 "Access
 * Denied" (server: AkamaiGHost) for requests with no/empty User-Agent, but
 * consistently allows a normal, honestly-identifying one through - this
 * isn't spoofing a browser, just supplying the header a well-behaved HTTP
 * client sends anyway. GHL-30's real-world first run hit exactly this
 * (32/32 teams "unavailable"); this is what fixes it.
 */
public with sharing class ESPNRetrieveData {
  private static final String USER_AGENT = 'GoldenHelmetLeague-PlayerNewsService/1.0';

  public static HttpResponse espnGetCallout(String url) {
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(url);
    req.setMethod('GET');
    req.setHeader('User-Agent', USER_AGENT);
    req.setHeader('Accept', 'application/json');
    HttpResponse res = new HttpResponse();

    try {
      res = http.send(req);
      Logger.info('Calling ESPN API: GET method')
        .setHttpRequestDetails(req)
        .setHttpResponseDetails(res);
      Logger.saveLog();
    } catch (Exception e) {
      Logger.exception('Error making GET callout to ESPN', e);
      Logger.saveLog();
      throw new CalloutException(e.getMessage());
    }

    if (res.getStatusCode() != 200) {
      Logger.warn('Error making GET callout to ESPN: ' + res.getBody());
      Logger.saveLog();
      throw new CalloutException(res.getBody());
    }

    return res;
  }
}
