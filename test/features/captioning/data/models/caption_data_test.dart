import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_data.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';

void main() {
  group('CaptionData tags', () {
    test('round-trips tags through JSON', () {
      final CaptionData data = CaptionData(
        id: 'img-1',
        filename: 'a.jpg',
        captions: <String, CaptionEntry>{},
        tags: const <String>['sunset', 'landscape'],
      );
      final CaptionData restored = CaptionData.fromJson(data.toJson());
      expect(restored.tags, <String>['sunset', 'landscape']);
    });

    test('defaults tags to empty list when absent in JSON (legacy DB)', () {
      final CaptionData restored = CaptionData.fromJson(<String, dynamic>{
        'id': 'img-1',
        'filename': 'a.jpg',
        'captions': <String, dynamic>{},
      });
      expect(restored.tags, <String>[]);
    });
  });
}
