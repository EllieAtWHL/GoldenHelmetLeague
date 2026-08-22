# Project conventions

## Apex: throwing errors from `@AuraEnabled` methods

Never hand-roll this pattern in a `catch` block:

```apex
catch (Exception e) {
  Logger.exception('...', e);
  Logger.saveLog();
  throw new AuraHandledException(e.getMessage());
}
```

Nebula Logger's `Logger.exception()` + `Logger.saveLog()`, called directly
before a `throw` in the same catch block, has been observed to swallow that
throw — the raw underlying exception escapes to the client instead of the
intended `AuraHandledException`, so the friendly message never gets shown.
Separately, `AuraHandledException`'s constructor message doesn't reliably
survive being serialized back to an LWC without an explicit `.setMessage()`
call. See `AuraExceptionHelper.cls` for the full writeup and GHL-24 in Jira
for the investigation and repro.

Use `AuraExceptionHelper.logAndBuild(...)` instead, and let the caller's own
`throw` statement do the throwing:

```apex
catch (Exception e) {
  throw AuraExceptionHelper.logAndBuild('Error doing X', e);
}
```

See the ApexDoc on `AuraExceptionHelper.cls` for the three overloads
(exception-only, message-only, and message-plus-cause) and when to use each.

This applies to every `@AuraEnabled` method across the codebase, not just
the classes it's already been applied to — if you're adding a new one and
it needs to throw a client-facing error, use the helper from the start.
