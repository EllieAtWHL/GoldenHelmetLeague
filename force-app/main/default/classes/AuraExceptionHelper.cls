public class AuraExceptionHelper {
  public static AuraHandledException logAndBuild(
    String logMessage,
    Exception cause
  ) {
    return logAndBuild(logMessage, cause.getMessage(), cause);
  }

  public static AuraHandledException logAndBuild(
    String logMessage,
    String clientMessage
  ) {
    return logAndBuild(logMessage, clientMessage, null);
  }

  public static AuraHandledException logAndBuild(
    String logMessage,
    String clientMessage,
    Exception cause
  ) {
    // Logging must never be able to prevent this exception from reaching the
    // caller - Logger.exception()/saveLog() have been observed to swallow a
    // throw statement that follows them in the same catch block (GHL-24).
    try {
      if (cause != null) {
        Logger.exception(logMessage, cause);
      } else {
        Logger.warn(logMessage);
      }
      Logger.saveLog();
    } catch (Exception loggingException) {
    }

    // The message passed to the constructor doesn't reliably survive being
    // serialized back to an LWC - setMessage() must also be called.
    AuraHandledException ex = new AuraHandledException(clientMessage);
    ex.setMessage(clientMessage);
    return ex;
  }
}
