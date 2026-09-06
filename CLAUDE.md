# Project conventions

## Workflow: after merging a PR

Merging a PR isn't the end of the task — always do both of these
straight after, not as a separate later cleanup pass:

1. **Update the Jira ticket the PR delivers.** Transition it to Done
   (via whatever intermediate statuses the workflow requires, e.g.
   To Do → In Progress → Done). A merged PR with its ticket still sitting
   in To Do makes the board lie about what's actually shipped. When you
   make the Done transition, also add a comment on the ticket confirming
   exactly what was delivered (link the merged PR, and call out anything
   that shipped differently than the ticket originally described) — so
   the ticket is a true record of the outcome, not just the plan.
2. **Delete the branch, locally and on the remote.** Once a PR is merged
   and you're happy with it, the branch has done its job — remove it in
   both places so `git branch -a` only ever shows branches that represent
   live work.

If a branch being deleted is the base of another open PR, GitHub will
auto-close that PR (its base ref disappears). Check for stacked PRs
before deleting, and if one does get closed, recreate it targeting the
correct base — check whether it had existing comments/reviews worth
preserving first.

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
This is **not a documented Nebula Logger bug** — no external source confirms
it, and it's characterized by a permanent test
(`AuraExceptionHelperTest.characterizationTest_LoggerExceptionAndSaveLogBeforeThrow_CanSwallowTheThrow`)
rather than taken on faith; re-run that test if you want to check it still
reproduces. Separately, `AuraHandledException`'s constructor message isn't
guaranteed to be what `.getMessage()` returns later, so `AuraExceptionHelper`
also calls `.setMessage()` explicitly as a defensive habit — this one is
**not confirmed by Salesforce's own docs** either, just commonly recommended
in the developer community. See the ApexDoc on `AuraExceptionHelper.cls` for
the full, honestly-sourced writeup, and GHL-24 in Jira for the investigation.

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
