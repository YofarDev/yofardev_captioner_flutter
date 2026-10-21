import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';

void main() {
  group('IdeogramCaption.isIdeogramJson', () {
    test('rejects plain text and empty strings', () {
      expect(IdeogramCaption.isIdeogramJson('hello'), isFalse);
      expect(IdeogramCaption.isIdeogramJson(''), isFalse);
    });

    test('rejects JSON without the required keys', () {
      expect(IdeogramCaption.isIdeogramJson('{"foo": 1}'), isFalse);
    });

    test(
      'accepts JSON with high_level_description and compositional_deconstruction',
      () {
        const String json =
            '{"high_level_description": "a cat", "compositional_deconstruction": {}}';
        expect(IdeogramCaption.isIdeogramJson(json), isTrue);
      },
    );

    test('rejects malformed JSON', () {
      expect(IdeogramCaption.isIdeogramJson('{not json'), isFalse);
    });
  });
}
