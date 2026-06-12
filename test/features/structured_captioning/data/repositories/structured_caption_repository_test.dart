import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/vlm_analysis.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/sam_process_service.dart';

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
        expect(analysis.objects[0].visibleText, isNull);
        expect(analysis.style.medium, 'photograph'); // default
      });

      test('parses text objects correctly', () {
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
              'bbox': <int>[100, 100, 300, 300],
            },
          ],
        };

        final VlmAnalysis analysis = repo.parseAnalysisJson(json);
        expect(analysis.objects[0].hasText, isTrue);
        expect(analysis.objects[0].visibleText, 'STOP');
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
            VlmObject(name: 'Tree', desc: 'oak tree', hasText: false),
            VlmObject(name: 'Bench', desc: 'wooden park bench', hasText: false),
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
            VlmObject(name: 'Chair', desc: 'red chair', hasText: false),
            VlmObject(name: 'Chair', desc: 'blue chair', hasText: false),
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

      test('builds text elements for objects with hasText=true', () {
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
              hasText: true,
              visibleText: 'STOP',
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
              hasText: false,
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
          objects: <VlmObject>[
            VlmObject(name: 'Rock', desc: 'grey rock', hasText: false),
          ],
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
  });
}
