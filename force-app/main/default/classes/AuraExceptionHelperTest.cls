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
}
