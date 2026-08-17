@IsTest
public class HttpFormBuilderTest {
  @IsTest
  static void getContentType_Success() {
    Test.startTest();
    String contentType = HttpFormBuilder.GetContentType();
    Test.stopTest();

    Assert.isTrue(
      contentType.startsWith(
        'multipart/form-data; charset="UTF-8"; boundary="'
      ),
      'Content type did not contain the expected multipart boundary format'
    );
  }

  @IsTest
  static void writeBoundary_NoArgs_ReturnsBase64EncodedBoundary() {
    Test.startTest();
    String boundary = HttpFormBuilder.WriteBoundary();
    Test.stopTest();

    Blob decoded = EncodingUtil.base64Decode(boundary);
    String decodedValue = decoded.toString();

    Assert.isTrue(
      decodedValue.startsWith('--') && decodedValue.endsWith('\r\n'),
      'Boundary was not wrapped with -- and a trailing CRLF as expected'
    );
  }

  @IsTest
  static void writeBoundary_EndingTypeCr_PrependsSingleLineBreak() {
    Test.startTest();
    String boundary = HttpFormBuilder.WriteBoundary(
      HttpFormBuilder.EndingType.Cr
    );
    Test.stopTest();

    Blob decoded = EncodingUtil.base64Decode(boundary);
    String decodedValue = decoded.toString();

    Assert.isTrue(
      decodedValue.startsWith('\n--') && decodedValue.endsWith('--'),
      'Boundary was not prepended with a single line break as expected'
    );
  }

  @IsTest
  static void writeBoundary_EndingTypeNone_PrependsFullLineBreak() {
    Test.startTest();
    String boundary = HttpFormBuilder.WriteBoundary(
      HttpFormBuilder.EndingType.None
    );
    Test.stopTest();

    Blob decoded = EncodingUtil.base64Decode(boundary);
    String decodedValue = decoded.toString();

    Assert.isTrue(
      decodedValue.startsWith('\r\n--') && decodedValue.endsWith('--'),
      'Boundary was not prepended with a full line break as expected'
    );
  }

  @IsTest
  static void writeBoundary_EndingTypeCrLf_NoExtraLineBreakPrepended() {
    Test.startTest();
    String boundary = HttpFormBuilder.WriteBoundary(
      HttpFormBuilder.EndingType.CrLf
    );
    Test.stopTest();

    Blob decoded = EncodingUtil.base64Decode(boundary);
    String decodedValue = decoded.toString();

    Assert.isTrue(
      decodedValue.startsWith('--') && decodedValue.endsWith('--'),
      'Boundary should not have an extra line break prepended for CrLf ending type'
    );
  }

  @IsTest
  static void writeBodyParameter_Success_ContainsKeyAndValue() {
    Test.startTest();
    String bodyParameter = HttpFormBuilder.WriteBodyParameter(
      'DATA',
      'test value'
    );
    Test.stopTest();

    Blob decoded = EncodingUtil.base64Decode(bodyParameter);
    String decodedValue = decoded.toString();

    Assert.isTrue(
      decodedValue.contains('Content-Disposition: form-data; name="DATA"'),
      'Body parameter did not contain the expected content disposition header'
    );
    Assert.isTrue(
      decodedValue.contains('test value'),
      'Body parameter did not contain the expected value'
    );
  }

  @IsTest
  static void writeBodyParameter_ValueRequiringPadding_StillDecodesCorrectly() {
    // A single-character value is highly likely to produce a base64-padded
    // segment, exercising the SafelyPad padding-removal loop.
    Test.startTest();
    String bodyParameter = HttpFormBuilder.WriteBodyParameter('K', 'V');
    Test.stopTest();

    Blob decoded = EncodingUtil.base64Decode(bodyParameter);
    String decodedValue = decoded.toString();

    Assert.isTrue(
      decodedValue.contains('name="K"'),
      'Body parameter did not contain the expected key'
    );
    Assert.isTrue(
      decodedValue.contains('V'),
      'Body parameter did not contain the expected value'
    );
    Assert.isFalse(
      EncodingUtil.base64Encode(decoded).endsWith('='),
      'Encoded content should have been padded with spaces to avoid base64 padding characters'
    );
  }
}
