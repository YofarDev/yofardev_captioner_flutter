import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/captioning/data/services/caption_service.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/vlm_analysis.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/bbox_highlight_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/sam_process_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/structured_prompt_loader.dart';

import 'structured_caption_repository_test.mocks.dart';

@GenerateMocks(<Type>[
  CaptionService,
  BboxHighlightService,
  StructuredPromptLoader,
  SamProcessService,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton(() => Logger('TestRepo'));
  });

  group('StructuredCaptionRepository', () {
    late StructuredCaptionRepository repo;

    setUp(() {
      repo = StructuredCaptionRepository();
    });

    // =========================================================================
    // isLikelyGroup
    // =========================================================================

    group('isLikelyGroup', () {
      test('returns true for plural names', () {
        expect(repo.isLikelyGroup('Chairs', ''), isTrue);
        expect(repo.isLikelyGroup('Potted Plants', ''), isTrue);
        expect(repo.isLikelyGroup('Curtains', ''), isTrue);
        expect(repo.isLikelyGroup('Books', ''), isTrue);
      });

      test('returns false for singular names', () {
        expect(repo.isLikelyGroup('Chair', ''), isFalse);
        expect(repo.isLikelyGroup('Cat', ''), isFalse);
        expect(repo.isLikelyGroup('Window', ''), isFalse);
      });

      test('returns false for words ending in "ss"', () {
        expect(repo.isLikelyGroup('Glass', ''), isFalse);
        expect(repo.isLikelyGroup('Dress', ''), isFalse);
        expect(repo.isLikelyGroup('Cross', ''), isFalse);
        expect(repo.isLikelyGroup('Moss', ''), isFalse);
      });

      test('returns true when description has group keywords', () {
        expect(
          repo.isLikelyGroup('Flower', 'a group of flowers in a vase'),
          isTrue,
        );
        expect(
          repo.isLikelyGroup('Tree', 'cluster of trees in background'),
          isTrue,
        );
        expect(
          repo.isLikelyGroup('Bottle', 'a row of bottles on shelf'),
          isTrue,
        );
        expect(
          repo.isLikelyGroup('Candle', 'a pair of candles on table'),
          isTrue,
        );
        expect(repo.isLikelyGroup('Book', 'several books stacked'), isTrue);
        expect(repo.isLikelyGroup('Plate', 'multiple plates arranged'), isTrue);
        expect(repo.isLikelyGroup('Mug', 'a set of mugs'), isTrue);
        expect(repo.isLikelyGroup('Herb', 'a bunch of herbs'), isTrue);
      });

      test('returns false for singular name without group description', () {
        expect(
          repo.isLikelyGroup('Cat', 'a small orange cat sitting on a mat'),
          isFalse,
        );
        expect(repo.isLikelyGroup('Table', 'a wooden dining table'), isFalse);
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

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);

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

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);
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

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);
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

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);
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
            <String, dynamic>{
              'name': 'Car',
              'desc': 'a car',
              'has_text': false,
            },
          ],
        };

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);
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
              'bbox': <String>[
                'x',
                'y',
                'z',
                'w',
              ], // non-numeric → throws → null
            },
            <String, dynamic>{
              'name': 'D',
              'desc': '',
              'has_text': false,
              'bbox': <int>[-50, 200, 5000, 400], // out of range → clamped
            },
          ],
        };

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);
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
        expect(repo.normalizeBbox(<int>[100, 200, 300, 400]), <int>[
          200,
          100,
          400,
          300,
        ]);
      });

      test('clamps out-of-range values to [0,1000]', () {
        expect(repo.normalizeBbox(<int>[-50, 200, 1500, 400]), <int>[
          200,
          0,
          400,
          1000,
        ]);
      });

      test('orders inverted corners', () {
        // Given as [x2,y2,x1,y1] effectively → still normalized correctly.
        expect(repo.normalizeBbox(<int>[300, 400, 100, 200]), <int>[
          200,
          100,
          400,
          300,
        ]);
      });

      test('returns null for zero-area / line boxes', () {
        expect(
          repo.normalizeBbox(<int>[100, 100, 100, 400]),
          isNull,
        ); // zero width
        expect(
          repo.normalizeBbox(<int>[100, 200, 300, 200]),
          isNull,
        ); // zero height
      });

      test('returns null for malformed input', () {
        expect(repo.normalizeBbox(null), isNull);
        expect(repo.normalizeBbox(<int>[1, 2, 3]), isNull);
        expect(repo.normalizeBbox('notabox'), isNull);
      });
    });

    // =========================================================================
    // computeAspectRatio
    // =========================================================================

    group('computeAspectRatio', () {
      test('reduces clean ratios by gcd', () {
        expect(repo.computeAspectRatio(1920, 1080), '16:9');
        expect(repo.computeAspectRatio(1024, 1024), '1:1');
        expect(repo.computeAspectRatio(1080, 1920), '9:16');
        expect(repo.computeAspectRatio(1500, 500), '3:1');
      });

      test('snaps ugly fractions to a small-denominator ratio', () {
        // 1023x768 ≈ 1.330 → 4:3 (1.333) is the closest with denom ≤ 16.
        expect(repo.computeAspectRatio(1023, 768), '4:3');
      });

      test('returns 1:1 for non-positive dimensions', () {
        expect(repo.computeAspectRatio(0, 0), '1:1');
        expect(repo.computeAspectRatio(-10, 100), '1:1');
      });
    });

    // =========================================================================
    // extractJsonObject
    // =========================================================================

    group('extractJsonObject', () {
      test('returns clean object as-is', () {
        const String raw = '{"a": 1}';
        expect(repo.extractJsonObject(raw), raw);
      });

      test('strips markdown fences', () {
        const String raw = '```json\n{"a": 1}\n```';
        expect(repo.extractJsonObject(raw), '{"a": 1}');
      });

      test('falls back to outermost braces with prose around it', () {
        const String raw =
            'Here is the caption:\n{"high_level_description": "x"}\nDone.';
        expect(repo.extractJsonObject(raw), '{"high_level_description": "x"}');
      });

      test('returns null when no object is present', () {
        expect(repo.extractJsonObject('no json here at all'), isNull);
      });
    });

    // =========================================================================
    // matchDetectionsToObjects
    // =========================================================================

    group('matchDetectionsToObjects', () {
      test('returns VLM bboxes when no SAM detections', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 300, 300]),
          const VlmObjectBboxPair(name: 'Dog', bbox: <int>[400, 400, 600, 600]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          <SamDetection>[],
          vlmObjects,
        );

        expect(result, hasLength(2));
        expect(result[0].name, 'Cat');
        expect(result[0].bbox, <int>[100, 100, 300, 300]);
        expect(result[1].name, 'Dog');
      });

      test('matches SAM detections to same-name VLM objects by proximity', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          // Cat at top-left (center ~150,150)
          const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 200, 200]),
          // Cat at bottom-right (center ~700,700)
          const VlmObjectBboxPair(name: 'Cat', bbox: <int>[650, 650, 750, 750]),
        ];

        final List<SamDetection> samDetections = <SamDetection>[
          // SAM finds a cat near bottom-right
          const SamDetection(name: 'Cat', bbox: <int>[660, 660, 740, 740]),
          // SAM finds a cat near top-left
          const SamDetection(name: 'Cat', bbox: <int>[110, 110, 190, 190]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result, hasLength(2));
        // First VLM cat (top-left) matched to second SAM (top-left).
        expect(result[0].bbox, <int>[110, 110, 190, 190]);
        // Second VLM cat (bottom-right) matched to first SAM (bottom-right).
        expect(result[1].bbox, <int>[660, 660, 740, 740]);
      });

      test('assigns single SAM detection to closest VLM object (1:N)', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(
            name: 'Chair',
            bbox: <int>[100, 100, 200, 200],
          ),
          const VlmObjectBboxPair(
            name: 'Chair',
            bbox: <int>[700, 700, 800, 800],
          ),
        ];

        // Only one SAM detection — should go to the closest one.
        final List<SamDetection> samDetections = <SamDetection>[
          const SamDetection(name: 'Chair', bbox: <int>[690, 690, 810, 810]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result, hasLength(2));
        // First chair: no SAM match → VLM fallback.
        expect(result[0].bbox, <int>[100, 100, 200, 200]);
        // Second chair: SAM matched.
        expect(result[1].bbox, <int>[690, 690, 810, 810]);
      });

      test('fills unmatched VLM objects with their own bbox', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(
            name: 'Tree',
            bbox: <int>[100, 100, 300, 300],
          ),
          const VlmObjectBboxPair(name: 'Car', bbox: <int>[500, 500, 700, 700]),
        ];

        // SAM only detects Tree.
        final List<SamDetection> samDetections = <SamDetection>[
          const SamDetection(name: 'Tree', bbox: <int>[110, 110, 290, 290]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result[0].bbox, <int>[110, 110, 290, 290]); // SAM
        expect(result[1].bbox, <int>[500, 500, 700, 700]); // VLM fallback
      });

      test('handles objects with null bboxes', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(name: 'Sky'),
          const VlmObjectBboxPair(
            name: 'Bird',
            bbox: <int>[200, 200, 300, 300],
          ),
        ];

        final List<SamDetection> samDetections = <SamDetection>[
          const SamDetection(name: 'Bird', bbox: <int>[210, 210, 290, 290]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result[0].bbox, isNull); // Sky: no bbox anywhere
        expect(result[1].bbox, <int>[210, 210, 290, 290]); // Bird: SAM
      });

      test(
        'rejects SAM detection that landed on a different region (IoU gate)',
        () {
          // Mirrors the real failure: SAM returned the Nyon-sign bbox for BOTH
          // the "Nyon Sign" and "Text Banner" prompts. The Text-Banner SAM bbox
          // does not overlap the VLM's top-banner bbox at all (IoU = 0), so it
          // must fall back to the VLM bbox instead of duplicating Nyon Sign.
          final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
            const VlmObjectBboxPair(
              name: 'Nyon Sign',
              bbox: <int>[356, 756, 492, 988],
            ),
            const VlmObjectBboxPair(
              name: 'Text Banner',
              bbox: <int>[0, 0, 88, 998],
            ),
          ];

          final List<SamDetection> samDetections = <SamDetection>[
            // SAM correctly refines Nyon Sign.
            const SamDetection(
              name: 'Nyon Sign',
              bbox: <int>[353, 735, 504, 1000],
            ),
            // SAM wrongly returns the Nyon-sign region again for "Text Banner".
            const SamDetection(
              name: 'Text Banner',
              bbox: <int>[353, 735, 505, 1000],
            ),
          ];

          final List<SamDetection> result = repo.matchDetectionsToObjects(
            samDetections,
            vlmObjects,
          );

          expect(result, hasLength(2));
          // Nyon Sign: SAM overlaps VLM well (IoU ~0.79) → kept.
          expect(result[0].bbox, <int>[353, 735, 504, 1000]);
          // Text Banner: SAM overlaps VLM with IoU 0 → rejected, VLM bbox used.
          expect(result[1].bbox, <int>[0, 0, 88, 998]);
        },
      );

      test('keeps SAM detection that overlaps the VLM region (IoU gate)', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 300, 300]),
        ];
        final List<SamDetection> samDetections = <SamDetection>[
          // Slightly larger but mostly overlapping — IoU well above 0.1.
          const SamDetection(name: 'Cat', bbox: <int>[90, 90, 320, 320]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result[0].bbox, <int>[90, 90, 320, 320]);
      });

      test('accepts SAM detection when VLM bbox is null (no spatial hint)', () {
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(name: 'Sky'), // no bbox
        ];
        final List<SamDetection> samDetections = <SamDetection>[
          const SamDetection(name: 'Sky', bbox: <int>[0, 0, 500, 500]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result[0].bbox, <int>[0, 0, 500, 500]);
      });

      test('1:N assignment respects IoU gate (rejects far SAM)', () {
        // Two same-name VLM objects; the only SAM detection is near neither.
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 200, 200]),
          const VlmObjectBboxPair(name: 'Cat', bbox: <int>[700, 700, 800, 800]),
        ];
        final List<SamDetection> samDetections = <SamDetection>[
          const SamDetection(name: 'Cat', bbox: <int>[400, 400, 500, 500]),
        ];

        final List<SamDetection> result = repo.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        // Neither VLM cat overlaps the SAM detection → both fall back to VLM.
        expect(result[0].bbox, <int>[100, 100, 200, 200]);
        expect(result[1].bbox, <int>[700, 700, 800, 800]);
      });
    });

    // =========================================================================
    // buildIdeogramCaption
    // =========================================================================

    group('buildIdeogramCaption', () {
      test('builds caption with elements from analysis and detections', () {
        const VlmAnalysis analysis = VlmAnalysis(
          highLevelDescription: 'A park scene',
          style: VlmStyle(
            medium: 'photograph',
            aesthetics: 'serene',
            lighting: 'golden hour',
            photoOrArt: 'DSLR',
          ),
          background: 'clear blue sky',
          objects: <VlmObject>[
            VlmObject(name: 'Tree', desc: 'oak tree'),
            VlmObject(name: 'Bench', desc: 'wooden park bench'),
          ],
        );

        final List<SamDetection> detections = <SamDetection>[
          const SamDetection(name: 'Tree', bbox: <int>[100, 100, 500, 500]),
          const SamDetection(name: 'Bench', bbox: <int>[600, 200, 800, 400]),
        ];

        final Map<int, List<String>> palettes = <int, List<String>>{
          0: <String>['#2D5016', '#8B6914'],
          1: <String>['#8B4513', '#DEB887'],
        };

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>['#87CEEB', '#228B22'],
          analysis,
          detections,
          palettes,
          null,
        );

        expect(caption.highLevelDescription, 'A park scene');
        expect(
          caption.compositionalDeconstruction.background,
          'clear blue sky',
        );
        expect(caption.compositionalDeconstruction.elements, hasLength(2));
        expect(
          caption.compositionalDeconstruction.elements[0].desc,
          'oak tree',
        );
        expect(
          caption.compositionalDeconstruction.elements[0].colorPalette,
          <String>['#2D5016', '#8B6914'],
        );
        expect(
          caption.compositionalDeconstruction.elements[1].desc,
          'wooden park bench',
        );
        expect(
          caption.compositionalDeconstruction.elements[1].colorPalette,
          <String>['#8B4513', '#DEB887'],
        );
      });

      test('assigns per-index palettes for duplicate-named objects', () {
        const VlmAnalysis analysis = VlmAnalysis(
          highLevelDescription: 'Dining room',
          style: VlmStyle(
            medium: 'photograph',
            aesthetics: 'modern',
            lighting: 'overhead',
            photoOrArt: '',
          ),
          background: 'white wall',
          objects: <VlmObject>[
            VlmObject(name: 'Chair', desc: 'red chair'),
            VlmObject(name: 'Chair', desc: 'blue chair'),
          ],
        );

        final List<SamDetection> detections = <SamDetection>[
          const SamDetection(name: 'Chair', bbox: <int>[100, 100, 300, 400]),
          const SamDetection(name: 'Chair', bbox: <int>[600, 100, 800, 400]),
        ];

        // Index-keyed palettes — each chair gets its own.
        final Map<int, List<String>> palettes = <int, List<String>>{
          0: <String>['#FF0000', '#CC0000'],
          1: <String>['#0000FF', '#0000CC'],
        };

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          analysis,
          detections,
          palettes,
          null,
        );

        expect(caption.compositionalDeconstruction.elements, hasLength(2));
        // First chair: red palette
        expect(
          caption.compositionalDeconstruction.elements[0].desc,
          'red chair',
        );
        expect(
          caption.compositionalDeconstruction.elements[0].colorPalette,
          <String>['#FF0000', '#CC0000'],
        );
        // Second chair: blue palette
        expect(
          caption.compositionalDeconstruction.elements[1].desc,
          'blue chair',
        );
        expect(
          caption.compositionalDeconstruction.elements[1].colorPalette,
          <String>['#0000FF', '#0000CC'],
        );
      });

      test('builds text elements for objects with type=text', () {
        const VlmAnalysis analysis = VlmAnalysis(
          highLevelDescription: '',
          style: VlmStyle(
            medium: 'photograph',
            aesthetics: '',
            lighting: '',
            photoOrArt: '',
          ),
          background: '',
          objects: <VlmObject>[
            VlmObject(
              name: 'Sign',
              desc: 'stop sign',
              type: 'text',
              text: 'STOP',
            ),
          ],
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          analysis,
          <SamDetection>[
            const SamDetection(name: 'Sign', bbox: <int>[100, 100, 300, 300]),
          ],
          <int, List<String>>{},
          null,
        );

        expect(caption.compositionalDeconstruction.elements[0].type, 'text');
        expect(caption.compositionalDeconstruction.elements[0].text, 'STOP');
      });

      test('falls back to VLM bbox when SAM detection has no bbox', () {
        const VlmAnalysis analysis = VlmAnalysis(
          highLevelDescription: '',
          style: VlmStyle(
            medium: 'photograph',
            aesthetics: '',
            lighting: '',
            photoOrArt: '',
          ),
          background: '',
          objects: <VlmObject>[
            VlmObject(
              name: 'Cat',
              desc: 'tabby',
              bbox: <int>[100, 100, 300, 300],
            ),
          ],
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          analysis,
          <SamDetection>[const SamDetection(name: 'Cat')],
          <int, List<String>>{},
          null,
        );

        expect(caption.compositionalDeconstruction.elements[0].bbox, <int>[
          100,
          100,
          300,
          300,
        ]);
      });

      test('omits per-element palette when not in map', () {
        const VlmAnalysis analysis = VlmAnalysis(
          highLevelDescription: '',
          style: VlmStyle(
            medium: 'photograph',
            aesthetics: '',
            lighting: '',
            photoOrArt: '',
          ),
          background: '',
          objects: <VlmObject>[VlmObject(name: 'Rock', desc: 'grey rock')],
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>['#808080'],
          analysis,
          <SamDetection>[const SamDetection(name: 'Rock')],
          <int, List<String>>{}, // no palette for index 0
          null,
        );

        expect(
          caption.compositionalDeconstruction.elements[0].colorPalette,
          isNull,
        );
      });
    });

    // =========================================================================
    // computeIou
    // =========================================================================

    group('computeIou', () {
      test('returns 1.0 for identical bboxes', () {
        expect(
          repo.computeIou(<int>[100, 100, 300, 300], <int>[100, 100, 300, 300]),
          1.0,
        );
      });

      test('returns 0 for non-overlapping bboxes', () {
        expect(
          repo.computeIou(<int>[0, 0, 50, 50], <int>[60, 60, 100, 100]),
          0.0,
        );
      });

      test('returns 0 for null or malformed input', () {
        expect(repo.computeIou(null, <int>[0, 0, 10, 10]), 0.0);
        expect(repo.computeIou(<int>[0, 0], <int>[0, 0, 10, 10]), 0.0);
      });

      test('computes partial overlap', () {
        // a = 100x100 = 10000, b = 100x100 = 10000, intersection = 50x50 = 2500
        // union = 10000 + 10000 - 2500 = 17500 → IoU = 2500/17500 ≈ 0.1429.
        final double iou = repo.computeIou(
          <int>[0, 0, 100, 100],
          <int>[50, 50, 150, 150],
        );
        expect(iou, closeTo(0.1429, 0.001));
      });

      test('Nyon Sign VLM vs SAM bbox has high IoU (~0.79)', () {
        final double iou = repo.computeIou(
          <int>[356, 756, 492, 988],
          <int>[353, 735, 504, 1000],
        );
        expect(iou, closeTo(0.79, 0.02));
      });

      test('Text Banner VLM vs wrong SAM bbox has IoU 0', () {
        final double iou = repo.computeIou(
          <int>[0, 0, 88, 998],
          <int>[353, 735, 505, 1000],
        );
        expect(iou, 0.0);
      });
    });
  });

  group('recaptionElement', () {
    late MockCaptionService mockCaption;
    late MockBboxHighlightService mockHighlight;
    late MockStructuredPromptLoader mockLoader;
    late StructuredCaptionRepository repo;

    final LlmConfig config = LlmConfig(
      id: 'cfg',
      name: 'cfg',
      model: 'vlm',
      providerType: LlmProviderType.remote,
    );

    const IdeogramCaption caption = IdeogramCaption(
      highLevelDescription: 'a desk',
      styleDescription: IdeogramStyleDescription(
        aesthetics: 'a',
        lighting: 'l',
        medium: 'photograph',
        colorPalette: <String>['#000000'],
      ),
      compositionalDeconstruction: IdeogramCompositionalDeconstruction(
        background: 'wall',
        elements: <IdeogramElement>[
          IdeogramElement(
            type: 'obj',
            bbox: <int>[100, 100, 400, 400],
            desc: 'old desc',
            colorPalette: <String>['#111111'],
          ),
        ],
      ),
    );

    setUp(() {
      mockCaption = MockCaptionService();
      mockHighlight = MockBboxHighlightService();
      mockLoader = MockStructuredPromptLoader();
      when(mockLoader.loadElementRecaptionPrompt()).thenAnswer(
        (_) async =>
            'PROMPT {elementIndex} {elementBbox} {existingJson} {instructionsBlock}',
      );
      when(
        mockHighlight.renderHighlightedJpeg(any, any),
      ).thenAnswer((_) async => '/tmp/highlight.jpg');
      when(mockHighlight.cleanup(any)).thenAnswer((_) async {});
      repo = StructuredCaptionRepository(
        captionService: mockCaption,
        bboxHighlightService: mockHighlight,
        promptLoader: mockLoader,
      );
    });

    test(
      'updates desc, preserves bbox/type/colorPalette for obj element',
      () async {
        when(mockCaption.getCaption(any, any, any)).thenAnswer(
          (_) async =>
              '{"desc": "fresh desc", "has_text": false, "visible_text": null}',
        );

        final IdeogramElement updated = await repo.recaptionElement(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
          elementIndex: 0,
        );

        final IdeogramElement original =
            caption.compositionalDeconstruction.elements.first;
        expect(updated.desc, 'fresh desc');
        expect(updated.bbox, original.bbox);
        expect(updated.type, original.type);
        expect(updated.colorPalette, original.colorPalette);
        expect(updated.text, isNull);
        expect(identical(updated, original), isFalse);
      },
    );

    test('overwrites text for text element when has_text true', () async {
      const IdeogramCaption textCaption = IdeogramCaption(
        highLevelDescription: 'h',
        styleDescription: IdeogramStyleDescription(
          aesthetics: '',
          lighting: '',
          medium: 'photograph',
          colorPalette: <String>[],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: '',
          elements: <IdeogramElement>[
            IdeogramElement(
              type: 'text',
              desc: 'old',
              bbox: <int>[0, 0, 50, 50],
            ),
          ],
        ),
      );
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '{"desc": "a sign", "has_text": true, "visible_text": "HELLO"}',
      );

      final IdeogramElement updated = await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: textCaption,
        elementIndex: 0,
      );

      expect(updated.desc, 'a sign');
      expect(updated.text, 'HELLO');
      expect(updated.type, 'text');
    });

    test('clears text when VLM says has_text false on a text element', () async {
      const IdeogramCaption textCaption = IdeogramCaption(
        highLevelDescription: 'h',
        styleDescription: IdeogramStyleDescription(
          aesthetics: '',
          lighting: '',
          medium: 'photograph',
          colorPalette: <String>[],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: '',
          elements: <IdeogramElement>[
            IdeogramElement(
              type: 'text',
              desc: 'old',
              bbox: <int>[0, 0, 50, 50],
              text: 'OLDTEXT',
            ),
          ],
        ),
      );
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '{"desc": "illegible scrawl", "has_text": false, "visible_text": null}',
      );

      final IdeogramElement updated = await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: textCaption,
        elementIndex: 0,
      );

      expect(updated.desc, 'illegible scrawl');
      expect(updated.text, '');
    });

    test(
      'throws FormatException when VLM returns desc missing/empty',
      () async {
        when(
          mockCaption.getCaption(any, any, any),
        ).thenAnswer((_) async => '{"has_text": false, "visible_text": null}');
        await expectLater(
          repo.recaptionElement(
            config: config,
            imageFile: File('img.png'),
            currentCaption: caption,
            elementIndex: 0,
          ),
          throwsA(isA<FormatException>()),
        );
        verify(mockHighlight.cleanup('/tmp/highlight.jpg')).called(1);
      },
    );

    test('throws FormatException on unparseable response', () async {
      when(
        mockCaption.getCaption(any, any, any),
      ).thenAnswer((_) async => 'not json at all');
      await expectLater(
        repo.recaptionElement(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
          elementIndex: 0,
        ),
        throwsA(isA<FormatException>()),
      );
      // Cleanup must still fire on parse failure.
      verify(mockHighlight.cleanup('/tmp/highlight.jpg')).called(1);
    });

    test(
      'throws FormatException when response is a JSON array, not object',
      () async {
        when(
          mockCaption.getCaption(any, any, any),
        ).thenAnswer((_) async => '[{"desc": "x"}]');
        await expectLater(
          repo.recaptionElement(
            config: config,
            imageFile: File('img.png'),
            currentCaption: caption,
            elementIndex: 0,
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('parses fenced JSON', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '```json\n{"desc": "ok", "has_text": false, "visible_text": null}\n```',
      );
      final IdeogramElement updated = await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
        elementIndex: 0,
      );
      expect(updated.desc, 'ok');
    });

    test('propagates CaptionService errors and cleans up temp file', () async {
      when(
        mockCaption.getCaption(any, any, any),
      ).thenThrow(Exception('network down'));

      await expectLater(
        repo.recaptionElement(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
          elementIndex: 0,
        ),
        throwsA(isA<Exception>()),
      );

      verify(mockHighlight.cleanup('/tmp/highlight.jpg')).called(1);
    });

    test('substitutes template tokens including instructions block', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async => '{"desc": "x", "has_text": false, "visible_text": null}',
      );
      await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
        elementIndex: 0,
        instructions: 'focus on the branding',
      );

      final String capturedPrompt =
          verify(mockCaption.getCaption(any, any, captureAny)).captured.single
              as String;

      expect(capturedPrompt, contains('PROMPT 0 [100, 100, 400, 400]'));
      expect(capturedPrompt, contains('[100, 100, 400, 400]'));
      expect(capturedPrompt, contains('high_level_description'));
      expect(capturedPrompt, contains('focus on the branding'));
    });

    test('omits instructions block when instructions is null', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async => '{"desc": "x", "has_text": false, "visible_text": null}',
      );
      await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
        elementIndex: 0,
      );

      final String capturedPrompt =
          verify(mockCaption.getCaption(any, any, captureAny)).captured.single
              as String;

      expect(capturedPrompt, isNot(contains('Additional instructions')));
    });

    test('throws RangeError when elementIndex is out of range', () async {
      await expectLater(
        repo.recaptionElement(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
          elementIndex: 99,
        ),
        throwsA(isA<RangeError>()),
      );
      verifyNever(mockHighlight.renderHighlightedJpeg(any, any));
    });

    test('throws StateError when target element has no bbox', () async {
      const IdeogramCaption noBbox = IdeogramCaption(
        highLevelDescription: 'h',
        styleDescription: IdeogramStyleDescription(
          aesthetics: '',
          lighting: '',
          medium: 'photograph',
          colorPalette: <String>[],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: '',
          elements: <IdeogramElement>[
            IdeogramElement(type: 'obj', desc: 'no box'),
          ],
        ),
      );
      await expectLater(
        repo.recaptionElement(
          config: config,
          imageFile: File('img.png'),
          currentCaption: noBbox,
          elementIndex: 0,
        ),
        throwsA(isA<StateError>()),
      );
      verifyNever(mockHighlight.renderHighlightedJpeg(any, any));
    });
  });

  group('computeSamBboxes', () {
    late StructuredCaptionRepository repo;
    late MockSamProcessService mockSam;

    setUp(() {
      mockSam = MockSamProcessService();
      repo = StructuredCaptionRepository(samProcessService: mockSam);
    });

    IdeogramCaption captionWith({
      required List<IdeogramElement> elements,
    }) =>
        IdeogramCaption(
          highLevelDescription: 'hld',
          styleDescription: const IdeogramStyleDescription(
            aesthetics: 'a',
            lighting: 'l',
            medium: 'photograph',
            colorPalette: <String>['#000000'],
          ),
          compositionalDeconstruction: IdeogramCompositionalDeconstruction(
            background: 'bg',
            elements: elements,
          ),
        );

    test('returns empty map when no elements have bboxes', () async {
      final IdeogramCaption c = captionWith(
        elements: <IdeogramElement>[
          const IdeogramElement(type: 'obj', desc: 'no box'),
        ],
      );
      final Map<int, List<int>> result = await repo.computeSamBboxes(
        imageFile: File('img.png'),
        caption: c,
      );
      expect(result, isEmpty);
      verifyNever(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      );
    });

    test('skips likely-group elements and elements without a bbox', () async {
      final IdeogramCaption c = captionWith(
        elements: <IdeogramElement>[
          // 0: eligible — singular, has bbox.
          const IdeogramElement(
            type: 'obj',
            desc: 'a single cat',
            bbox: <int>[100, 100, 200, 200],
          ),
          // 1: group — plural name. Skipped.
          const IdeogramElement(
            type: 'obj',
            desc: 'Books',
            bbox: <int>[300, 300, 400, 400],
          ),
        ],
      );

      when(
        mockSam.detectObjects(
          'img.png',
          <String>['a single cat'],
          vlmBboxes: <List<int>?>[
            <int>[100, 100, 200, 200],
          ],
        ),
      ).thenAnswer((_) async => <SamDetection>[
        const SamDetection(
          name: 'a single cat',
          bbox: <int>[110, 110, 210, 210],
        ),
      ]);

      final Map<int, List<int>> result = await repo.computeSamBboxes(
        imageFile: File('img.png'),
        caption: c,
      );

      expect(result, <int, List<int>>{
        0: <int>[110, 110, 210, 210],
      });
    });

    test('passes through VLM bbox when SAM finds no match', () async {
      final IdeogramCaption c = captionWith(
        elements: <IdeogramElement>[
          const IdeogramElement(
            type: 'obj',
            desc: 'cat',
            bbox: <int>[100, 100, 200, 200],
          ),
        ],
      );

      // SAM returns nothing.
      when(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      ).thenAnswer((_) async => <SamDetection>[]);

      final Map<int, List<int>> result = await repo.computeSamBboxes(
        imageFile: File('img.png'),
        caption: c,
      );

      // matchDetectionsToObjects fills unmatched slots with the original VLM
      // bbox, and computeSamBboxes returns that result as-is — so even when
      // SAM finds no detection, the caller still gets a usable bbox per
      // element and the canvas always has something to render.
      expect(result, <int, List<int>>{
        0: <int>[100, 100, 200, 200],
      });
    });

    test('returns empty map and swallows errors from SamProcessService',
        () async {
      final IdeogramCaption c = captionWith(
        elements: <IdeogramElement>[
          const IdeogramElement(
            type: 'obj',
            desc: 'cat',
            bbox: <int>[100, 100, 200, 200],
          ),
        ],
      );

      when(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      ).thenThrow(Exception('python gone'));

      final Map<int, List<int>> result = await repo.computeSamBboxes(
        imageFile: File('img.png'),
        caption: c,
      );

      expect(result, isEmpty);
    });
  });
}
