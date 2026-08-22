/**
 * Thrown when MFL's API responds with HTTP 200 but its own JSON body
 * indicates an application-level error, e.g.:
 *   {"encoding":"utf-8","version":"1.0","error":{"$t":"Invalid league ID 24312"}}
 * The exception's message is MFL's own error text, so it can be shown to
 * the end user directly instead of being guessed at by the caller.
 */
public class MFLApiException extends Exception {
}
