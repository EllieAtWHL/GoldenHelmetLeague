/**
 * Builds an AuraHandledException that is safe to throw from any
 * `@AuraEnabled` method's catch block (see GHL-24 for the investigation):
 *
 * 1. Nebula Logger's `Logger.exception()` is documented to log at ERROR,
 *    save the log, and then RETHROW the exception it was given (its source
 *    ends in `throw apexException;`). So in a catch block, any `throw` that
 *    follows `Logger.exception(...)` never runs - the original raw exception
 *    (DmlException, NullPointerException, etc.) escapes to the client instead
 *    of the intended AuraHandledException. This is intended Nebula behavior,
 *    not a bug (originally investigated in GHL-24 before the cause was
 *    known; identified in GHL-43). It is also characterized by
 *    AuraExceptionHelperTest.characterizationTest_LoggerExceptionAndSaveLogBeforeThrow_CanSwallowTheThrow().
 *    To log an exception WITHOUT rethrowing it, use
 *    `Logger.error(message).setExceptionDetails(e)` instead. This method
 *    isolates logging in its own try/catch, which catches Logger.exception()'s
 *    rethrow so it can never prevent the exception it returns from being
 *    thrown.
 * 2. AuraHandledException's constructor message is not guaranteed to be
 *    what `.getMessage()` returns later - calling `.setMessage()` explicitly
 *    afterward is a common defensive habit in the Salesforce developer
 *    community for this reason. This is NOT confirmed by Salesforce's own
 *    official docs, which throw via the constructor alone in their
 *    canonical example. Kept here as a low-cost precaution, not a proven
 *    requirement - safe to remove if it's ever shown to be unnecessary.
 *
 * USE THIS instead of hand-rolling:
 *   catch (Exception e) {
 *     Logger.exception('...', e);
 *     Logger.saveLog();
 *     throw new AuraHandledException(e.getMessage());   // <- never runs
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
    // caller - Logger.exception() rethrows `cause` by design, so that rethrow
    // is caught and discarded here (GHL-24, GHL-43).
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
