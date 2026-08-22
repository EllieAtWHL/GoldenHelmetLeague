@IsTest
public class AuraExceptionHelperTest {
  @IsTest
  static void logAndBuild_WithCause_ReturnsExceptionWithClientMessage() {
    Exception cause = new CalloutException('technical detail');

    Test.startTest();
    AuraHandledException result = AuraExceptionHelper.logAndBuild(
      'log message for cause variant',
      cause
    );
    Test.stopTest();

    Assert.areEqual('technical detail', result.getMessage());
  }

  @IsTest
  static void logAndBuild_WithExplicitClientMessage_ReturnsExceptionWithThatMessage() {
    Exception cause = new CalloutException('technical detail');

    Test.startTest();
    AuraHandledException result = AuraExceptionHelper.logAndBuild(
      'log message',
      'friendly client message',
      cause
    );
    Test.stopTest();

    Assert.areEqual('friendly client message', result.getMessage());
  }

  @IsTest
  static void logAndBuild_NoCause_ReturnsExceptionWithClientMessage() {
    Test.startTest();
    AuraHandledException result = AuraExceptionHelper.logAndBuild(
      'log message with no cause',
      'friendly client message with no cause'
    );
    Test.stopTest();

    Assert.areEqual(
      'friendly client message with no cause',
      result.getMessage()
    );
  }

  @IsTest
  static void logAndBuild_ReturnsExceptionRatherThanThrowingIt() {
    // The caller is responsible for the throw statement - this lets the
    // stack trace point at the actual throw site.
    Test.startTest();
    AuraHandledException result = AuraExceptionHelper.logAndBuild(
      'log message',
      'client message'
    );
    Test.stopTest();

    Assert.isNotNull(result, 'A built exception should have been returned');
  }

  // The two tests below exist purely as durable, re-runnable evidence for
  // GHL-24. They are not a documented Nebula Logger bug - no external source
  // for this was found; searching turned up the opposite claim (Nebula
  // Logger is designed around platform events specifically so logging
  // doesn't interfere with exception propagation). This is a characterization
  // of behavior observed in this org, kept here instead of only in a
  // deleted scratch class, so the claim in AuraExceptionHelper's ApexDoc can
  // actually be checked rather than taken on faith.

  @IsTest
  static void characterizationTest_LoggerExceptionAndSaveLogBeforeThrow_CanSwallowTheThrow() {
    // The exact pattern AuraExceptionHelper exists to replace, written out
    // inline (not via any production class) so this characterizes the
    // Logger/platform behavior itself, independent of our own code.
    NFL_Team__c invalidRecord = new NFL_Team__c(
      Name = '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345' // 85 chars, exceeds the 80-char Name field limit
    );

    Boolean threwAuraHandledException = false;
    Boolean threwSomethingElse = false;

    Test.startTest();
    try {
      try {
        upsert new List<NFL_Team__c>{ invalidRecord };
      } catch (Exception e) {
        Logger.exception('characterization test log message', e);
        Logger.saveLog();
        throw new AuraHandledException(e.getMessage());
      }
    } catch (AuraHandledException ahe) {
      threwAuraHandledException = true;
    } catch (Exception other) {
      threwSomethingElse = true;
    }
    Test.stopTest();

    Assert.isTrue(
      threwSomethingElse,
      'Expected the original exception to escape unwrapped, characterizing the ' +
        'behavior AuraExceptionHelper guards against. If this fails, that behavior ' +
        'no longer reproduces in this org - AuraExceptionHelper is still safe to ' +
        'keep using, but its ApexDoc historical justification could be revisited.'
    );
    Assert.isFalse(
      threwAuraHandledException,
      'Expected the throw new AuraHandledException(...) to never be reached.'
    );
  }

  @IsTest
  static void logAndBuild_SameFailureScenarioAsCharacterizationTest_DoesNotSwallowTheException() {
    NFL_Team__c invalidRecord = new NFL_Team__c(
      Name = '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345'
    );

    AuraHandledException result;

    Test.startTest();
    try {
      upsert new List<NFL_Team__c>{ invalidRecord };
    } catch (Exception e) {
      result = AuraExceptionHelper.logAndBuild(
        'characterization test log message',
        e
      );
    }
    Test.stopTest();

    Assert.isNotNull(
      result,
      'AuraExceptionHelper.logAndBuild should return a value under the exact ' +
      'failure scenario that swallows a bare throw in the test above'
    );
  }
}
