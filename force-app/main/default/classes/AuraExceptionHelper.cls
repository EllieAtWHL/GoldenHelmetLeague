/**
 * Builds an AuraHandledException that is safe to throw from any
 * `@AuraEnabled` method's catch block, working around two platform/package
 * quirks (see GHL-24 for the investigation and original repro):
 *
 * 1. Nebula Logger's `Logger.exception()` + `Logger.saveLog()`, called
 *    directly before a `throw` in the same catch block, can swallow that
 *    throw - the original raw exception (DmlException, NullPointerException,
 *    etc.) escapes to the client instead of the intended AuraHandledException.
 *    This method isolates logging in its own try/catch so it can never
 *    prevent the exception it returns from being thrown.
 * 2. AuraHandledException's constructor message does not reliably survive
 *    serialization back to an LWC - `.setMessage()` must also be called.
 *    This is a documented Salesforce platform quirk, unrelated to Logger.
 *
 * USE THIS instead of hand-rolling:
 *   catch (Exception e) {
 *     Logger.exception('...', e);
 *     Logger.saveLog();
 *     throw new AuraHandledException(e.getMessage());   // <- can silently not run
 *   }
 *
 * INSTEAD WRITE:
 *   catch (Exception e) {
 *     throw AuraExceptionHelper.logAndBuild('Error doing X', e);
 *   }
 *
 * Note this method BUILDS and RETURNS the exception rather than throwing it
 * itself, so the caller's own `throw` statement is what appears in the stack
 * trace / log entry - keep the `throw` at the call site, not inside a
 * wrapper around this call.
 */
public class AuraExceptionHelper {
  /**
   * Logs `cause` and returns an AuraHandledException whose client-facing
   * message is `cause.getMessage()`. Use when the underlying exception's own
   * message is already appropriate to show the user.
   */
  public static AuraHandledException logAndBuild(
    String logMessage,
    Exception cause
  ) {
    return logAndBuild(logMessage, cause.getMessage(), cause);
  }

  /**
   * Logs `clientMessage` (no underlying exception) and returns an
   * AuraHandledException with that message. Use for validation-style
   * failures that aren't caused by a caught exception, e.g. a business rule
   * violation detected via an if-check.
   */
  public static AuraHandledException logAndBuild(
    String logMessage,
    String clientMessage
  ) {
    return logAndBuild(logMessage, clientMessage, null);
  }

  /**
   * Logs `cause` (if provided) under `logMessage`, then returns an
   * AuraHandledException whose client-facing message is `clientMessage`.
   * Use when the message you want to show the user should differ from the
   * underlying exception's own message (e.g. adding context, or hiding a
   * technical detail).
   */
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
