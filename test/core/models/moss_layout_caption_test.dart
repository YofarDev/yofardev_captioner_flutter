import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';

void main() {
  group('MossLayoutCaption.fromJson', () {
    test('parses a full draft with summary meta, canvas and palette', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      expect(caption.width, 1536);
      expect(caption.height, 1024);
      expect(caption.summary.caption, contains('ceramic cup'));
      expect(caption.summary.meta, <String>[
        'product campaign',
        'studio photography',
      ]);
      expect(caption.summary.canvas, 'single');
      expect(caption.summary.palette, <String>['ivory']);
      expect(caption.items, hasLength(3));
      expect(caption.items[1].label, 'text');
      expect(caption.items[1].text, '把日常，过成诗。');
      expect(caption.items[0].bbox, <int>[176, 224, 800, 864]);
    });

    test('applies lenient defaults for missing keys', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        const <String, dynamic>{},
      );
      expect(caption.width, 1024);
      expect(caption.height, 1024);
      expect(caption.summary.caption, '');
      expect(caption.summary.canvas, isNull);
      expect(caption.items, isEmpty);
    });

    test('item without label defaults to object', () {
      final MossItem item = MossItem.fromJson(const <String, dynamic>{
        'caption': 'a cup',
      });
      expect(item.label, 'object');
      expect(item.tags, isEmpty);
    });
  });

  group('MossLayoutCaption.toJson key order', () {
    test('top-level keys in schema order', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      expect(caption.toJson().keys.toList(), <String>[
        'width',
        'height',
        'bbox_coord_space',
        'bbox_format',
        'summary',
        'items',
      ]);
    });

    test('summary keys: meta, canvas, caption, palette', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      expect(caption.summary.toJson().keys.toList(), <String>[
        'meta',
        'canvas',
        'caption',
        'palette',
      ]);
    });

    test('item keys for object vs text items', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      expect(caption.items[0].toJson().keys.toList(), <String>[
        'label',
        'caption',
        'bbox',
      ]);
      expect(caption.items[1].toJson().keys.toList(), <String>[
        'label',
        'caption',
        'text',
        'bbox',
      ]);
    });
  });

  group('MossLayoutCaption.toJsonString round-trip', () {
    test('compact string round-trips through fromJson', () {
      final MossLayoutCaption original = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      final MossLayoutCaption parsed = MossLayoutCaption.fromJson(
        jsonDecode(original.toJsonString()) as Map<String, dynamic>,
      );
      expect(parsed, original);
      expect(parsed.toJsonString(), original.toJsonString());
    });

    test('emits no whitespace and preserves non-ASCII', () {
      const MossLayoutCaption caption = MossLayoutCaption(
        width: 16,
        height: 16,
        summary: MossSummary(caption: '把日常'),
        items: <MossItem>[
          MossItem(
            label: 'text',
            caption: 'green title',
            text: '一杯温暖\n一刻从容',
            bbox: <int>[1, 1, 15, 15],
          ),
        ],
      );
      final String json = caption.toJsonString();
      expect(json.contains('\n'), isFalse);
      expect(json, contains('把日常'));
      expect(json, contains(r'一杯温暖\n一刻从容'));
    });
  });

  group('isMossJson / hasEmptySummaryCaption', () {
    test('accepts a MOSS layout draft', () {
      expect(MossLayoutCaption.isMossJson(_fullDraftJson), isTrue);
    });

    test('rejects Ideogram JSON, plain text and invalid JSON', () {
      expect(
        MossLayoutCaption.isMossJson(
          '{"high_level_description":"a","compositional_deconstruction":{}}',
        ),
        isFalse,
      );
      expect(MossLayoutCaption.isMossJson('just a caption'), isFalse);
      expect(MossLayoutCaption.isMossJson('{broken'), isFalse);
      expect(MossLayoutCaption.isMossJson('{"summary":"not a map"}'), isFalse);
    });

    test('empty summary caption detection', () {
      const String empty = '{"summary":{"caption":""},"items":[]}';
      const String full = '{"summary":{"caption":"x"},"items":[]}';
      expect(MossLayoutCaption.hasEmptySummaryCaption(empty), isTrue);
      expect(MossLayoutCaption.hasEmptySummaryCaption(full), isFalse);
      expect(MossLayoutCaption.hasEmptySummaryCaption('nonsense'), isFalse);
    });
  });

  group('toCompiledPromptString', () {
    test('matches the spec example: cup bbox [176,224,800,864] on 1536x1024 '
        'compiles to centered yxyx [-288,-592,352,32]', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      final Map<String, dynamic> compiled =
          jsonDecode(caption.toCompiledPromptString()) as Map<String, dynamic>;
      expect(compiled.containsKey('width'), isFalse);
      expect(compiled.containsKey('height'), isFalse);
      expect(compiled.containsKey('bbox_coord_space'), isFalse);
      expect(compiled.containsKey('bbox_format'), isFalse);
      expect(
        (compiled['items'] as List<dynamic>).first as Map<String, dynamic>,
        containsPair('bbox', <int>[-288, -592, 352, 32]),
      );
    });

    test('compiled output is one physical line', () {
      final MossLayoutCaption caption = MossLayoutCaption.fromJson(
        jsonDecode(_fullDraftJson) as Map<String, dynamic>,
      );
      expect(caption.toCompiledPromptString().contains('\n'), isFalse);
    });

    test('rejects out-of-bounds boxes instead of clipping', () {
      const MossLayoutCaption caption = MossLayoutCaption(
        width: 16,
        height: 16,
        summary: MossSummary(caption: 'x'),
        items: <MossItem>[
          MossItem(caption: 'overflow', bbox: <int>[0, 0, 17, 8]),
        ],
      );
      expect(caption.toCompiledPromptString, throwsA(isA<StateError>()));
    });
  });
}

const String _fullDraftJson = '''
{
  "width": 1536,
  "height": 1024,
  "bbox_coord_space": "abs",
  "bbox_format": "xyxy",
  "summary": {
    "meta": ["product campaign", "studio photography"],
    "canvas": "single",
    "caption": "A warm studio campaign for a handmade ceramic cup, with an ivory backdrop, soft side lighting and restrained dark-green typography.",
    "palette": ["ivory"]
  },
  "items": [
    {
      "label": "object",
      "caption": "An ivory ceramic cup with a rounded handle, fine speckled glaze.",
      "bbox": [176, 224, 800, 864]
    },
    {
      "label": "text",
      "caption": "Large dark-green Chinese title in crisp lettering.",
      "text": "把日常，过成诗。",
      "bbox": [928, 272, 1408, 448]
    },
    {
      "label": "text",
      "caption": "Smaller dark-green Chinese supporting copy on two lines.",
      "text": "一杯温暖\\n一刻从容",
      "bbox": [928, 512, 1376, 656],
      "tags": ["supporting copy"],
      "palette": ["dark green"]
    }
  ]
}
''';
