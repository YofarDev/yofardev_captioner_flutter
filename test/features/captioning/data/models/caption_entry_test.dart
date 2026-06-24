import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';

void main() {
  group('CaptionEntry JSON', () {
    test('round-trips all fields', () {
      final CaptionEntry original = CaptionEntry(
        text: 'hello',
        model: 'cfg',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
        isEdited: true,
      );
      final CaptionEntry restored = CaptionEntry.fromJson(original.toJson());
      expect(restored.text, 'hello');
      expect(restored.model, 'cfg');
      expect(restored.timestamp, original.timestamp);
      expect(restored.isEdited, isTrue);
    });

    test('isEdited defaults to false when absent', () {
      final CaptionEntry restored = CaptionEntry.fromJson(
        const <String, dynamic>{'text': 'x'},
      );
      expect(restored.isEdited, isFalse);
      expect(restored.model, isNull);
    });

    test('copyWith overrides only supplied fields', () {
      const CaptionEntry base = CaptionEntry(text: 'a', model: 'm');
      final CaptionEntry updated = base.copyWith(text: 'b');
      expect(updated.text, 'b');
      expect(updated.model, 'm');
    });

    test('Equatable compares by all fields', () {
      const CaptionEntry a = CaptionEntry(text: 'x', model: 'm');
      const CaptionEntry b = CaptionEntry(text: 'x', model: 'm');
      expect(a, b);
      const CaptionEntry c = CaptionEntry(text: 'x', model: 'other');
      expect(a == c, isFalse);
    });
  });
}
