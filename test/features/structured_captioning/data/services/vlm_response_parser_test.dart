import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/vlm_analysis.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/vlm_response_parser.dart';

void main() {
  final VlmResponseParser parser = VlmResponseParser();

  VlmAnalysis analysisWith(List<VlmObject> objects) => VlmAnalysis(
    highLevelDescription: 'A park scene',
    style: const VlmStyle(
      medium: 'photograph',
      aesthetics: 'serene',
      lighting: 'golden hour',
      photoOrArt: 'DSLR',
    ),
    background: 'clear blue sky',
    objects: objects,
  );

  group('validateEnumerateOutput', () {
    test('empty object list is structurally sound', () {
      expect(
        parser.validateEnumerateOutput(analysisWith(<VlmObject>[])),
        isEmpty,
      );
    });

    test('flags exact duplicate bboxes', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(
          name: 'Tree',
          desc: 'oak tree',
          bbox: <int>[10, 20, 30, 40],
        ),
        const VlmObject(
          name: 'Bench',
          desc: 'bench',
          bbox: <int>[10, 20, 30, 40],
        ),
      ]);
      final List<String> defects = parser.validateEnumerateOutput(analysis);
      expect(defects, hasLength(1));
      expect(defects.single, contains('duplicate bbox at index 1'));
    });

    test('flags full-canvas bboxes', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(
          name: 'Sky',
          desc: 'everything',
          bbox: <int>[0, 0, 1000, 1000],
        ),
      ]);
      expect(
        parser.validateEnumerateOutput(analysis).single,
        contains('full-canvas bbox at index 0'),
      );
    });

    test('flags element-cap violations', () {
      final List<VlmObject> many = List<VlmObject>.generate(
        VlmResponseParser.multiStageElementCap + 1,
        (int i) => VlmObject(
          name: 'o$i',
          desc: 'd$i',
          bbox: <int>[i, i, i + 1, i + 1],
        ),
      );
      expect(
        parser.validateEnumerateOutput(analysisWith(many)).single,
        contains('element cap exceeded: 31 > 30'),
      );
    });
  });

  group('postMergeDefects', () {
    test('flags duplicate final bboxes with the final wording', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(name: 'A', desc: 'a', bbox: <int>[1, 2, 3, 4]),
        const VlmObject(name: 'B', desc: 'b', bbox: <int>[1, 2, 3, 4]),
      ]);
      expect(
        parser.postMergeDefects(analysis).single,
        contains('duplicate final bbox at index 1'),
      );
    });
  });

  group('parseEnrichResponse', () {
    test('merges desc and keeps identity fields through fences', () {
      const VlmObject original = VlmObject(
        name: 'Tree',
        desc: 'tree',
        bbox: <int>[10, 20, 30, 40],
      );
      final VlmObject? enriched = parser.parseEnrichResponse(
        '```json\n{"desc": "an ancient oak"}\n```',
        original,
      );
      expect(enriched, isNotNull);
      expect(enriched!.desc, 'an ancient oak');
      expect(enriched.name, 'Tree');
      expect(enriched.bbox, <int>[10, 20, 30, 40]);
    });

    test('missing or blank desc returns null (caller keeps terse desc)', () {
      const VlmObject original = VlmObject(name: 'Tree', desc: 'tree');
      expect(parser.parseEnrichResponse('{"desc": "  "}', original), isNull);
      expect(parser.parseEnrichResponse('not json at all', original), isNull);
    });
  });
}
