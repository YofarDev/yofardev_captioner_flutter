import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/vlm_analysis.dart';

void main() {
  group('VlmAnalysis JSON', () {
    test('fromJson parses raw VLM JSON (real use case)', () {
      // ponytail: parse-only — toJson emits nested objects, not Maps, so a
      // self round-trip is not how this model is used. It only ever ingests
      // raw VLM JSON via fromJson.
      final VlmAnalysis restored = VlmAnalysis.fromJson(const <String, dynamic>{
        'highLevelDescription': 'scene',
        'style': <String, dynamic>{
          'medium': 'photograph',
          'aesthetics': 'clean',
          'lighting': 'soft',
          'photo_or_art': 'DSLR',
        },
        'background': 'wall',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Cat',
            'desc': 'a cat',
            'bbox': <int>[10, 20, 30, 40],
          },
          <String, dynamic>{
            'name': 'Sign',
            'desc': 'a sign',
            'type': 'text',
            'text': 'HI',
          },
        ],
      });

      expect(restored.highLevelDescription, 'scene');
      expect(restored.background, 'wall');
      expect(restored.style.photoOrArt, 'DSLR');
      expect(restored.objects, hasLength(2));
      expect(restored.objects[0].name, 'Cat');
      expect(restored.objects[0].bbox, <int>[10, 20, 30, 40]);
      expect(restored.objects[1].type, 'text');
      expect(restored.objects[1].text, 'HI');
    });

    test('VlmStyle maps photoOrArt to snake_case key', () {
      final Map<String, dynamic> json = const VlmStyle(
        medium: 'm',
        aesthetics: 'a',
        lighting: 'l',
        photoOrArt: 'p',
      ).toJson();
      expect(json.containsKey('photo_or_art'), isTrue);
      expect(json['photo_or_art'], 'p');
      expect(json.containsKey('photoOrArt'), isFalse);
    });

    test('VlmObject type defaults to "obj" when absent', () {
      final VlmObject restored = VlmObject.fromJson(const <String, dynamic>{
        'name': 'X',
        'desc': 'd',
      });
      expect(restored.type, 'obj');
    });

    test('VlmObject preserves explicit type=text with text payload', () {
      final VlmObject restored = VlmObject.fromJson(const <String, dynamic>{
        'name': 'Banner',
        'desc': 'banner',
        'type': 'text',
        'text': 'SALE',
      });
      expect(restored.type, 'text');
      expect(restored.text, 'SALE');
    });
  });
}
