import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/utils/ideogram_json.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';

const String _validJson =
    '{"high_level_description":"a cat","compositional_deconstruction":{"background":"sky","elements":[]}}';

void main() {
  group('parseIdeogramCaptionJson', () {
    test('success: normalizes valid Ideogram JSON', () {
      final IdeogramJsonResult result = parseIdeogramCaptionJson(_validJson);

      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
      expect(result.normalized, isNotNull);
      expect(IdeogramCaption.isIdeogramJson(result.normalized!), isTrue);
      expect(result.normalized, contains('"high_level_description":"a cat"'));
      // Compact form has no structural whitespace (values may still contain spaces).
      expect(result.normalized, isNot(contains(', ')));
      expect(result.normalized, isNot(contains(': ')));
    });

    test('failure: missing compositional_deconstruction', () {
      final IdeogramJsonResult result = parseIdeogramCaptionJson(
        '{"high_level_description":"a cat"}',
      );

      expect(result.isSuccess, isFalse);
      expect(result.normalized, isNull);
      expect(result.error, isNotNull);
      expect(result.error, contains('compositional_deconstruction'));
    });

    test('failure: not a JSON object (plain text)', () {
      final IdeogramJsonResult result = parseIdeogramCaptionJson('a cute cat');

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('failure: JSON array, not object', () {
      final IdeogramJsonResult result = parseIdeogramCaptionJson('[1, 2, 3]');

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('failure: malformed JSON', () {
      final IdeogramJsonResult result = parseIdeogramCaptionJson('{not valid');

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Invalid JSON'));
    });

    test('failure: empty input', () {
      final IdeogramJsonResult result = parseIdeogramCaptionJson('');

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
