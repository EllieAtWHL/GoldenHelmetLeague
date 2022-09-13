public with sharing class CometdController {
    @AuraEnabled(cacheable=true)
    public static String getSessionId() {

        String sessionId;
        if(UserInfo.getSessionId() == null){
            sessionId = ManageGuestUser.getSessionId();
        } else{
            sessionId = UserInfo.getSessionId();
        }
        return sessionId;
    }
}