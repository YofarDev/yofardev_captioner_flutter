// Long JSON literals are concatenated without separators on purpose.
// ignore_for_file: missing_whitespace_between_adjacent_strings

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

  // =========================================================================
  // parseAnalysisJson
  // =========================================================================

  group('parseAnalysisJson', () {
    test('parses full VLM response with objects and bboxes', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'high_level_description': 'A cozy living room',
        'style': <String, dynamic>{
          'medium': 'photograph',
          'aesthetics': 'warm and inviting',
          'lighting': 'soft natural light',
          'photo_or_art': 'shot on 35mm film',
        },
        'background': 'beige wall with framed pictures',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sofa',
            'desc': 'large sectional sofa in gray fabric',
            'has_text': false,
            'bbox': <int>[100, 200, 400, 600],
          },
          <String, dynamic>{
            'name': 'Lamp',
            'desc': 'table lamp with brass base',
            'has_text': false,
            'bbox': <int>[50, 700, 200, 850],
          },
        ],
      };

      final VlmAnalysis analysis = parser.parseAnalysisJson(json);

      expect(analysis.highLevelDescription, 'A cozy living room');
      expect(analysis.background, 'beige wall with framed pictures');
      expect(analysis.style.medium, 'photograph');
      expect(analysis.objects, hasLength(2));
      expect(analysis.objects[0].name, 'Sofa');
      // Parser swaps VLM [x1,y1,x2,y2] → Ideogram [y1,x1,y2,x2].
      expect(analysis.objects[0].bbox, <int>[200, 100, 600, 400]);
      expect(analysis.objects[1].name, 'Lamp');
    });

    test('swaps bbox from [x1,y1,x2,y2] to [y1,x1,y2,x2]', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'high_level_description': '',
        'style': <String, dynamic>{
          'medium': 'photograph',
          'aesthetics': '',
          'lighting': '',
          'photo_or_art': '',
        },
        'background': '',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Dog',
            'desc': '',
            'has_text': false,
            'bbox': <int>[100, 200, 300, 400], // VLM sends x1,y1,x2,y2
          },
        ],
      };

      final VlmAnalysis analysis = parser.parseAnalysisJson(json);
      // Should be swapped to y1,x1,y2,x2 → [200, 100, 400, 300]
      expect(analysis.objects[0].bbox, <int>[200, 100, 400, 300]);
    });

    test('handles missing optional fields gracefully', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'high_level_description': 'Simple scene',
        'style': <String, dynamic>{},
        'background': '',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Tree', 'desc': '', 'has_text': false},
        ],
      };

      final VlmAnalysis analysis = parser.parseAnalysisJson(json);
      expect(analysis.objects[0].bbox, isNull);
      expect(analysis.objects[0].type, 'obj'); // default when type absent
      expect(analysis.objects[0].text, isNull);
      expect(analysis.style.medium, 'photograph'); // default
    });

    test('parses explicit type/text fields', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'high_level_description': '',
        'style': <String, dynamic>{
          'medium': 'photograph',
          'aesthetics': '',
          'lighting': '',
          'photo_or_art': '',
        },
        'background': '',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sign',
            'desc': 'a stop sign',
            'type': 'text',
            'text': 'STOP',
            'bbox': <int>[100, 100, 300, 300],
          },
          <String, dynamic>{
            'name': 'Car',
            'desc': 'a red car',
            'type': 'obj',
            'bbox': <int>[200, 100, 600, 400],
          },
        ],
      };

      final VlmAnalysis analysis = parser.parseAnalysisJson(json);
      expect(analysis.objects[0].type, 'text');
      expect(analysis.objects[0].text, 'STOP');
      expect(analysis.objects[1].type, 'obj');
      expect(analysis.objects[1].text, isNull);
    });

    test('falls back to has_text when type is absent (backwards compat)', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'high_level_description': '',
        'style': <String, dynamic>{
          'medium': 'photograph',
          'aesthetics': '',
          'lighting': '',
          'photo_or_art': '',
        },
        'background': '',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Sign',
            'desc': 'a stop sign',
            'has_text': true,
            'visible_text': 'STOP',
          },
          <String, dynamic>{'name': 'Car', 'desc': 'a car', 'has_text': false},
        ],
      };

      final VlmAnalysis analysis = parser.parseAnalysisJson(json);
      // Legacy has_text:true → derived type 'text', text from visible_text.
      expect(analysis.objects[0].type, 'text');
      expect(analysis.objects[0].text, 'STOP');
      // Legacy has_text:false → derived type 'obj'.
      expect(analysis.objects[1].type, 'obj');
    });

    test('drops malformed and degenerate bboxes during parse', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'high_level_description': '',
        'style': <String, dynamic>{
          'medium': 'photograph',
          'aesthetics': '',
          'lighting': '',
          'photo_or_art': '',
        },
        'background': '',
        'objects': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'A',
            'desc': '',
            'has_text': false,
            'bbox': <int>[100, 200, 300, 400], // valid x1,y1,x2,y2
          },
          <String, dynamic>{
            'name': 'B',
            'desc': '',
            'has_text': false,
            'bbox': <int>[50, 60], // wrong length → null
          },
          <String, dynamic>{
            'name': 'C',
            'desc': '',
            'has_text': false,
            'bbox': <String>['x', 'y', 'z', 'w'], // non-numeric → throws → null
          },
          <String, dynamic>{
            'name': 'D',
            'desc': '',
            'has_text': false,
            'bbox': <int>[-50, 200, 5000, 400], // out of range → clamped
          },
        ],
      };

      final VlmAnalysis analysis = parser.parseAnalysisJson(json);
      expect(analysis.objects[0].bbox, <int>[200, 100, 400, 300]); // A valid
      expect(analysis.objects[1].bbox, isNull); // B wrong length
      expect(analysis.objects[2].bbox, isNull); // C non-numeric
      expect(analysis.objects[3].bbox, <int>[200, 0, 400, 1000]); // D clamped
    });
  });

  // =========================================================================
  // normalizeBbox
  // =========================================================================

  group('normalizeBbox', () {
    test('swaps [x1,y1,x2,y2] to [y1,x1,y2,x2]', () {
      expect(parser.normalizeBbox(<int>[100, 200, 300, 400]), <int>[
        200,
        100,
        400,
        300,
      ]);
    });

    test('clamps out-of-range values to [0,1000]', () {
      expect(parser.normalizeBbox(<int>[-50, 200, 1500, 400]), <int>[
        200,
        0,
        400,
        1000,
      ]);
    });

    test('orders inverted corners', () {
      // Given as [x2,y2,x1,y1] effectively → still normalized correctly.
      expect(parser.normalizeBbox(<int>[300, 400, 100, 200]), <int>[
        200,
        100,
        400,
        300,
      ]);
    });

    test('returns null for zero-area / line boxes', () {
      expect(
        parser.normalizeBbox(<int>[100, 100, 100, 400]),
        isNull,
      ); // zero width
      expect(
        parser.normalizeBbox(<int>[100, 200, 300, 200]),
        isNull,
      ); // zero height
    });

    test('returns null for malformed input', () {
      expect(parser.normalizeBbox(null), isNull);
      expect(parser.normalizeBbox(<int>[1, 2, 3]), isNull);
      expect(parser.normalizeBbox('notabox'), isNull);
    });
  });

  // =========================================================================
  // normalizeBbox — vlmEmitsXyxy: false (VLM obeys the yxyx instruction)
  // =========================================================================

  group('normalizeBbox (vlmEmitsXyxy: false)', () {
    test('keeps [y1,x1,y2,x2] input as-is (no swap)', () {
      // VLM obeyed the yxyx instruction → input already yxyx, no swap.
      expect(
        parser.normalizeBbox(<int>[100, 200, 300, 400], vlmEmitsXyxy: false),
        <int>[100, 200, 300, 400],
      );
    });

    test('clamps out-of-range values to [0,1000] without swapping', () {
      // Input [y1,x1,y2,x2] = [-50, 200, 1500, 400] → clamp only.
      expect(
        parser.normalizeBbox(<int>[-50, 200, 1500, 400], vlmEmitsXyxy: false),
        <int>[0, 200, 1000, 400],
      );
    });

    test('orders inverted corners (yxyx interpretation)', () {
      // Input read as [y2,x2,y1,x1] effectively → still normalized correctly.
      expect(
        parser.normalizeBbox(<int>[300, 400, 100, 200], vlmEmitsXyxy: false),
        <int>[100, 200, 300, 400],
      );
    });

    test('returns null for zero-area / line boxes', () {
      expect(
        parser.normalizeBbox(<int>[100, 100, 100, 400], vlmEmitsXyxy: false),
        isNull,
      );
      expect(
        parser.normalizeBbox(<int>[100, 200, 300, 200], vlmEmitsXyxy: false),
        isNull,
      );
    });

    test('contrast: xyxy vs yxyx interpretation diverges', () {
      // Same four numbers, two orientations → different stored boxes. This is
      // the core contract: the flag flips input interpretation, output stays
      // yxyx.
      const List<int> raw = <int>[100, 200, 300, 400];
      expect(
        parser.normalizeBbox(raw), // default xyxy: reads x1,y1,x2,y2
        <int>[200, 100, 400, 300],
      );
      expect(
        parser.normalizeBbox(raw, vlmEmitsXyxy: false), // reads y1,x1,y2,x2
        <int>[100, 200, 300, 400],
      );
    });
  });

  // =========================================================================
  // parseAnalysisJson — orientation threaded through
  // =========================================================================

  group('parseAnalysisJson orientation', () {
    Map<String, dynamic> singleObjectBbox(List<int> bbox) => <String, dynamic>{
      'high_level_description': '',
      'style': <String, dynamic>{
        'medium': 'photograph',
        'aesthetics': '',
        'lighting': '',
        'photo_or_art': '',
      },
      'background': '',
      'objects': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'X',
          'desc': '',
          'has_text': false,
          'bbox': bbox,
        },
      ],
    };

    test('default (xyxy) swaps to yxyx', () {
      final VlmAnalysis analysis = parser.parseAnalysisJson(
        singleObjectBbox(<int>[100, 200, 300, 400]),
      );
      expect(analysis.objects[0].bbox, <int>[200, 100, 400, 300]);
    });

    test('vlmEmitsXyxy: false keeps yxyx input order', () {
      final VlmAnalysis analysis = parser.parseAnalysisJson(
        singleObjectBbox(<int>[100, 200, 300, 400]),
        vlmEmitsXyxy: false,
      );
      expect(analysis.objects[0].bbox, <int>[100, 200, 300, 400]);
    });
  });

  // =========================================================================
  // extractJsonObject
  // =========================================================================

  group('extractJsonObject', () {
    test('returns clean object as-is', () {
      const String raw = '{"a": 1}';
      expect(parser.extractJsonObject(raw), raw);
    });

    test('strips markdown fences', () {
      const String raw = '```json\n{"a": 1}\n```';
      expect(parser.extractJsonObject(raw), '{"a": 1}');
    });

    test('falls back to outermost braces with prose around it', () {
      const String raw =
          'Here is the caption:\n{"high_level_description": "x"}\nDone.';
      expect(parser.extractJsonObject(raw), '{"high_level_description": "x"}');
    });

    test('returns null when no object is present', () {
      expect(parser.extractJsonObject('no json here at all'), isNull);
    });

    test('returns null for truncated JSON instead of an unbalanced fragment', () {
      // Simulates a VLM response that was cut off by max_tokens: the
      // top-level object never closes, but an inner sub-object's `}`
      // exists. The old fallback returned the substring up to that inner
      // `}`, producing invalid JSON that threw the cryptic
      // "FormatException: unexpected end of input". Now it must return
      // null so the caller can emit a clear error.
      const String truncated =
          '{"high_level_description": "A crowd", "objects": [{"name": "person", "desc": "tall"}, {"name": "person2"';
      expect(parser.extractJsonObject(truncated), isNull);
    });
  });

  // =========================================================================
  // bboxAreaRatio
  // =========================================================================

  group('bboxAreaRatio', () {
    test('full canvas returns 1.0', () {
      expect(
        parser.bboxAreaRatio(<int>[0, 0, 1000, 1000]),
        closeTo(1.0, 0.001),
      );
    });

    test('quarter canvas returns ~0.25', () {
      expect(parser.bboxAreaRatio(<int>[0, 0, 500, 500]), closeTo(0.25, 0.001));
    });

    test('null returns 0.0', () {
      expect(parser.bboxAreaRatio(null), 0.0);
    });

    test('zero-area returns 0.0', () {
      expect(parser.bboxAreaRatio(<int>[100, 100, 100, 200]), 0.0);
    });

    test('malformed (wrong length) returns 0.0', () {
      expect(parser.bboxAreaRatio(<int>[1, 2, 3]), 0.0);
    });
  });

  // =========================================================================
  // normalizedNameSimilarity
  // =========================================================================

  group('normalizedNameSimilarity', () {
    test('identical names return 1.0', () {
      expect(parser.normalizedNameSimilarity('Plants', 'Plants'), 1.0);
    });

    test('overlapping words return fraction', () {
      expect(parser.normalizedNameSimilarity('potted plants', 'plants'), 1.0);
    });

    test('partial overlap', () {
      // "framed" is shared; "picture" ≠ "pictures" → 1/2 = 0.5.
      expect(
        parser.normalizedNameSimilarity('framed picture', 'framed pictures'),
        0.5,
      );
    });

    test('unrelated names return 0.0', () {
      expect(parser.normalizedNameSimilarity('Sofa', 'Windows'), 0.0);
    });

    test('empty strings return 0.0', () {
      expect(parser.normalizedNameSimilarity('', 'Sofa'), 0.0);
    });
  });

  // =========================================================================
  // pruneDuplicateObjects
  // =========================================================================

  group('pruneDuplicateObjects', () {
    VlmAnalysis analysisWith(List<VlmObject> objects) => VlmAnalysis(
      highLevelDescription: 'test',
      style: const VlmStyle(
        medium: 'photograph',
        aesthetics: '',
        lighting: '',
        photoOrArt: '',
      ),
      background: '',
      objects: objects,
    );

    test('removes duplicate same-bbox same-name objects', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(
          name: 'Bookshelf',
          desc: 'a',
          bbox: <int>[500, 540, 650, 860],
        ),
        const VlmObject(
          name: 'Bookshelf',
          desc: 'b',
          bbox: <int>[500, 540, 650, 860],
        ),
      ]);
      final VlmAnalysis pruned = parser.pruneDuplicateObjects(analysis);
      expect(pruned.objects, hasLength(1));
    });

    test('keeps objects with different bboxes', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(
          name: 'Lamp',
          desc: 'a',
          bbox: <int>[330, 410, 370, 470],
        ),
        const VlmObject(
          name: 'Sofa',
          desc: 'b',
          bbox: <int>[100, 100, 500, 400],
        ),
      ]);
      final VlmAnalysis pruned = parser.pruneDuplicateObjects(analysis);
      expect(pruned.objects, hasLength(2));
    });

    test('single object is not pruned', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(
          name: 'Lamp',
          desc: 'a',
          bbox: <int>[330, 410, 370, 470],
        ),
      ]);
      final VlmAnalysis pruned = parser.pruneDuplicateObjects(analysis);
      expect(pruned.objects, hasLength(1));
    });

    test('keeps objects with same bbox but different names (not similar)', () {
      final VlmAnalysis analysis = analysisWith(<VlmObject>[
        const VlmObject(name: 'Sofa', desc: 'a', bbox: <int>[0, 0, 1000, 1000]),
        const VlmObject(
          name: 'Plants',
          desc: 'b',
          bbox: <int>[0, 0, 1000, 1000],
        ),
      ]);
      final VlmAnalysis pruned = parser.pruneDuplicateObjects(analysis);
      expect(pruned.objects, hasLength(2));
    });
  });

  // =========================================================================
  // parsePartialVlmResponse
  // =========================================================================

  group('parsePartialVlmResponse', () {
    test('recovers complete objects from a truncated enumerate response', () {
      const String truncated =
          '{"high_level_description":"apartment","style":{"medium":"illustration",'
          '"aesthetics":"pastel","lighting":"bright","photo_or_art":"flat art"},'
          '"background":"pink walls","objects":['
          '{"name":"bed","type":"obj","desc":"yellow bed","bbox":[197,112,414,194]},'
          '{"name":"sofa","type":"obj","desc":"orange sofa","bbox":[669,328,938,452]},'
          '{"name":"plant","type":"obj","desc":"upper right plants","bbox":[790,102,975,228]},'
          '{"name":"plant","type":"obj","desc":"lower left';

      final VlmAnalysis analysis = parser.parsePartialVlmResponse(truncated);

      expect(analysis.highLevelDescription, 'apartment');
      expect(analysis.style.medium, 'illustration');
      expect(analysis.background, 'pink walls');
      expect(analysis.objects, hasLength(3));
      expect(analysis.objects.map((VlmObject o) => o.name), <String>[
        'bed',
        'sofa',
        'plant',
      ]);
    });
  });
}
