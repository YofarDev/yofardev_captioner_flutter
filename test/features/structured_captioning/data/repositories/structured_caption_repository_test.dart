import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';
import 'package:yofardev_captioner/core/models/structured_batch_overrides.dart';
import 'package:yofardev_captioner/core/models/structured_caption_document.dart';
import 'package:yofardev_captioner/core/utils/cancel_token.dart';
import 'package:yofardev_captioner/features/captioning/data/services/caption_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/vlm_analysis.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/bbox_highlight_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/color_extraction_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/sam_process_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/structured_prompt_loader.dart';
import 'package:yofardev_captioner/features/structured_captioning/domain/models/structured_mode.dart';
import 'structured_caption_repository_test.mocks.dart';

// Long JSON literals are concatenated without separators on purpose.
// ignore_for_file: missing_whitespace_between_adjacent_strings

@GenerateMocks(<Type>[
  CaptionService,
  BboxHighlightService,
  StructuredPromptLoader,
  SamProcessService,
  ColorExtractionService,
])
/// Matches a completed Either that is Left with the given [Failure] type.
Matcher isLeftFailure(Type type) => completion(
  predicate<Object?>(
    (Object? v) =>
        v is Either<Failure, dynamic> &&
        v.isLeft() &&
        v.getLeft().toNullable().runtimeType == type,
  ),
);

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

      // ---- StructuredBatchOverrides branches ----

      const VlmAnalysis baseAnalysis = VlmAnalysis(
        highLevelDescription: 'hld',
        style: VlmStyle(
          medium: 'photograph',
          aesthetics: 'orig-aesthetics',
          lighting: 'orig-lighting',
          photoOrArt: 'orig-photoOrArt',
        ),
        background: 'orig-background',
        objects: <VlmObject>[VlmObject(name: 'Cat', desc: 'a cat')],
      );

      test(
        'applies enabled medium/aesthetics/lighting/background overrides',
        () {
          const StructuredBatchOverrides overrides = StructuredBatchOverrides(
            enabled: true,
            overrideMedium: true,
            medium: 'oil painting',
            overrideAesthetics: true,
            aesthetics: 'moody',
            overrideLighting: true,
            lighting: 'chiaroscuro',
            overrideBackground: true,
            background: 'studio',
          );

          final IdeogramCaption caption = repo.buildIdeogramCaption(
            <String>[],
            baseAnalysis,
            <SamDetection>[const SamDetection(name: 'Cat')],
            <int, List<String>>{},
            overrides,
          );

          final IdeogramStyleDescription style = caption.styleDescription;
          expect(style.medium, 'oil painting');
          expect(style.aesthetics, 'moody');
          expect(style.lighting, 'chiaroscuro');
          expect(caption.compositionalDeconstruction.background, 'studio');
          // Non-photograph medium → isPhoto false → artStyle falls back to
          // photoOrArt, photo is null.
          expect(style.photo, isNull);
          expect(style.artStyle, 'orig-photoOrArt');
        },
      );

      test('routes styleMode=photo into the photo field', () {
        const StructuredBatchOverrides overrides = StructuredBatchOverrides(
          enabled: true,
          styleMode: 'photo',
          styleDetail: '35mm film grain',
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          baseAnalysis,
          <SamDetection>[const SamDetection(name: 'Cat')],
          <int, List<String>>{},
          overrides,
        );

        // medium stays 'photograph' → isPhoto true; styleMode photo wins.
        expect(caption.styleDescription.medium, 'photograph');
        expect(caption.styleDescription.photo, '35mm film grain');
        expect(caption.styleDescription.artStyle, isNull);
      });

      test('routes styleMode=art_style into the artStyle field', () {
        const StructuredBatchOverrides overrides = StructuredBatchOverrides(
          enabled: true,
          overrideMedium: true,
          medium: 'digital art',
          styleMode: 'art_style',
          styleDetail: 'cyberpunk',
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          baseAnalysis,
          <SamDetection>[const SamDetection(name: 'Cat')],
          <int, List<String>>{},
          overrides,
        );

        expect(caption.styleDescription.medium, 'digital art');
        expect(caption.styleDescription.artStyle, 'cyberpunk');
        expect(caption.styleDescription.photo, isNull);
      });

      test('does not apply overrides when enabled is false', () {
        // Every override flag is set, but the batch is disabled — the analysis
        // values must come through untouched.
        const StructuredBatchOverrides overrides = StructuredBatchOverrides(
          // ignore: avoid_redundant_argument_values
          enabled: false,
          overrideMedium: true,
          medium: 'oil painting',
          overrideAesthetics: true,
          aesthetics: 'moody',
          overrideLighting: true,
          lighting: 'chiaroscuro',
          overrideBackground: true,
          background: 'studio',
          styleMode: 'photo',
          styleDetail: 'ignored',
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          baseAnalysis,
          <SamDetection>[const SamDetection(name: 'Cat')],
          <int, List<String>>{},
          overrides,
        );

        final IdeogramStyleDescription style = caption.styleDescription;
        expect(style.medium, 'photograph');
        expect(style.aesthetics, 'orig-aesthetics');
        expect(style.lighting, 'orig-lighting');
        expect(
          caption.compositionalDeconstruction.background,
          'orig-background',
        );
        // isPhoto true + no styleMode override → photo from photoOrArt.
        expect(style.photo, 'orig-photoOrArt');
      });

      test('ignores an override whose flag is false even when enabled', () {
        const StructuredBatchOverrides overrides = StructuredBatchOverrides(
          enabled: true,
          // ignore: avoid_redundant_argument_values
          overrideMedium: false, // flag off → medium not overridden
          medium: 'ignored',
        );

        final IdeogramCaption caption = repo.buildIdeogramCaption(
          <String>[],
          baseAnalysis,
          <SamDetection>[const SamDetection(name: 'Cat')],
          <int, List<String>>{},
          overrides,
        );

        expect(caption.styleDescription.medium, 'photograph');
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

        final IdeogramElement updated = (await repo.recaptionElement(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
          elementIndex: 0,
        )).getRight().toNullable()!;

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

      final IdeogramElement updated = (await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: textCaption,
        elementIndex: 0,
      )).getRight().toNullable()!;

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

      final IdeogramElement updated = (await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: textCaption,
        elementIndex: 0,
      )).getRight().toNullable()!;

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
          isLeftFailure(FailureInvalidData),
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
        isLeftFailure(FailureInvalidData),
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
          isLeftFailure(FailureInvalidData),
        );
      },
    );

    test('parses fenced JSON', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '```json\n{"desc": "ok", "has_text": false, "visible_text": null}\n```',
      );
      final IdeogramElement updated = (await repo.recaptionElement(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
        elementIndex: 0,
      )).getRight().toNullable()!;
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
        isLeftFailure(FailureUnexpected),
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
        isLeftFailure(FailureUnexpected),
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
        isLeftFailure(FailureUnexpected),
      );
      verifyNever(mockHighlight.renderHighlightedJpeg(any, any));
    });
  });

  group('recaptionStyle', () {
    late MockCaptionService mockCaption;
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
        aesthetics: 'old-aesthetics',
        lighting: 'old-lighting',
        medium: 'photograph',
        photo: 'old camera',
        colorPalette: <String>['#111111', '#222222'],
      ),
      compositionalDeconstruction: IdeogramCompositionalDeconstruction(
        background: 'wall',
        elements: <IdeogramElement>[IdeogramElement(type: 'obj', desc: 'mug')],
      ),
    );

    setUp(() {
      mockCaption = MockCaptionService();
      mockLoader = MockStructuredPromptLoader();
      when(
        mockLoader.loadStyleRecaptionPrompt(),
      ).thenAnswer((_) async => 'STYLE PROMPT {existingJson}');
      repo = StructuredCaptionRepository(
        captionService: mockCaption,
        promptLoader: mockLoader,
      );
    });

    test(
      'swaps all four photo-medium fields and preserves colorPalette',
      () async {
        when(mockCaption.getCaption(any, any, any)).thenAnswer(
          (_) async =>
              '{"medium": "photograph", "aesthetics": "moody", '
              '"lighting": "golden hour", "photo_or_art": "50mm f/1.8"}',
        );

        final IdeogramStyleDescription updated = (await repo.recaptionStyle(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
        )).getRight().toNullable()!;

        expect(updated.medium, 'photograph');
        expect(updated.aesthetics, 'moody');
        expect(updated.lighting, 'golden hour');
        expect(updated.photo, '50mm f/1.8');
        expect(updated.artStyle, isNull);
        // Palette untouched — it has its own extraction flow.
        expect(updated.colorPalette, <String>['#111111', '#222222']);
      },
    );

    test(
      'medium flip routes photo_or_art into artStyle and nulls photo',
      () async {
        when(mockCaption.getCaption(any, any, any)).thenAnswer(
          (_) async =>
              '{"medium": "painting", "aesthetics": "baroque", '
              '"lighting": "chiaroscuro", "photo_or_art": "oil on canvas"}',
        );

        final IdeogramStyleDescription updated = (await repo.recaptionStyle(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
        )).getRight().toNullable()!;

        expect(updated.medium, 'painting');
        expect(updated.artStyle, 'oil on canvas');
        expect(updated.photo, isNull);
      },
    );

    test('preserves existing colorPalette when VLM omits it', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '{"medium": "photograph", "aesthetics": "a", '
            '"lighting": "l", "photo_or_art": "p"}',
      );

      final IdeogramStyleDescription updated = (await repo.recaptionStyle(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
      )).getRight().toNullable()!;

      expect(updated.colorPalette, caption.styleDescription.colorPalette);
    });

    test('substitutes the {existingJson} token into the prompt', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '{"medium": "photograph", "aesthetics": "a", '
            '"lighting": "l", "photo_or_art": "p"}',
      );

      await repo.recaptionStyle(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
      );

      final String capturedPrompt =
          verify(mockCaption.getCaption(any, any, captureAny)).captured.single
              as String;
      expect(capturedPrompt, contains('STYLE PROMPT'));
      // The existing caption JSON is injected for context.
      expect(capturedPrompt, contains('high_level_description'));
      expect(capturedPrompt, contains('a desk'));
    });

    test('parses fenced JSON', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '```json\n{"medium": "photograph", "aesthetics": "a", '
            '"lighting": "l", "photo_or_art": "p"}\n```',
      );

      final IdeogramStyleDescription updated = (await repo.recaptionStyle(
        config: config,
        imageFile: File('img.png'),
        currentCaption: caption,
      )).getRight().toNullable()!;

      expect(updated.medium, 'photograph');
    });

    test('throws FormatException when medium is missing', () async {
      when(mockCaption.getCaption(any, any, any)).thenAnswer(
        (_) async =>
            '{"aesthetics": "a", "lighting": "l", '
            '"photo_or_art": "p"}',
      );
      await expectLater(
        repo.recaptionStyle(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
        ),
        isLeftFailure(FailureInvalidData),
      );
    });

    test('throws FormatException on unparseable response', () async {
      when(
        mockCaption.getCaption(any, any, any),
      ).thenAnswer((_) async => 'not json at all');
      await expectLater(
        repo.recaptionStyle(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
        ),
        isLeftFailure(FailureInvalidData),
      );
    });

    test('throws FormatException when response is a JSON array', () async {
      when(
        mockCaption.getCaption(any, any, any),
      ).thenAnswer((_) async => '["photograph"]');
      await expectLater(
        repo.recaptionStyle(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
        ),
        isLeftFailure(FailureInvalidData),
      );
    });

    test('propagates CaptionService errors', () async {
      when(
        mockCaption.getCaption(any, any, any),
      ).thenThrow(Exception('network down'));
      await expectLater(
        repo.recaptionStyle(
          config: config,
          imageFile: File('img.png'),
          currentCaption: caption,
        ),
        isLeftFailure(FailureUnexpected),
      );
    });

    test('mapStyleResponse routes photo medium into photo field', () {
      const String raw =
          '{"medium": "photograph", "aesthetics": "a", '
          '"lighting": "l", "photo_or_art": "dslr"}';
      final IdeogramStyleDescription mapped = repo.mapStyleResponse(
        raw,
        <String>['#abc'],
      );
      expect(mapped.photo, 'dslr');
      expect(mapped.artStyle, isNull);
      expect(mapped.colorPalette, <String>['#abc']);
    });
  });

  group('computeSamBboxes', () {
    late StructuredCaptionRepository repo;
    late MockSamProcessService mockSam;

    setUp(() {
      mockSam = MockSamProcessService();
      repo = StructuredCaptionRepository(samProcessService: mockSam);
    });

    IdeogramCaption captionWith({required List<IdeogramElement> elements}) =>
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
      final Either<Failure, Map<int, List<int>>> either = await repo
          .computeSamBboxes(imageFile: File('img.png'), caption: c);
      expect(either.isRight(), isTrue);
      final Map<int, List<int>> result = either.getOrElse(
        (Failure f) => fail('unexpected failure: $f'),
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
      ).thenAnswer(
        (_) async => <SamDetection>[
          const SamDetection(
            name: 'a single cat',
            bbox: <int>[110, 110, 210, 210],
          ),
        ],
      );

      final Either<Failure, Map<int, List<int>>> either = await repo
          .computeSamBboxes(imageFile: File('img.png'), caption: c);
      expect(either.isRight(), isTrue);
      final Map<int, List<int>> result = either.getOrElse(
        (Failure f) => fail('unexpected failure: $f'),
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

      final Either<Failure, Map<int, List<int>>> either = await repo
          .computeSamBboxes(imageFile: File('img.png'), caption: c);
      expect(either.isRight(), isTrue);
      final Map<int, List<int>> result = either.getOrElse(
        (Failure f) => fail('unexpected failure: $f'),
      );

      // matchDetectionsToObjects fills unmatched slots with the original VLM
      // bbox, and computeSamBboxes returns that result as-is — so even when
      // SAM finds no detection, the caller still gets a usable bbox per
      // element and the canvas always has something to render.
      expect(result, <int, List<int>>{
        0: <int>[100, 100, 200, 200],
      });
    });

    test(
      'returns empty map and swallows errors from SamProcessService',
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

        final Either<Failure, Map<int, List<int>>> either = await repo
            .computeSamBboxes(imageFile: File('img.png'), caption: c);
        expect(either.isRight(), isTrue);
        final Map<int, List<int>> result = either.getOrElse(
          (Failure f) => fail('unexpected failure: $f'),
        );

        expect(result, isEmpty);
      },
    );
  });

  // ===========================================================================
  // generateStructuredCaption — the full pipeline. Stubs every collaborator so
  // we can assert on orchestration: progress emission, SAM subset selection
  // (group elements skipped), and graceful degradation when a step fails.
  // ===========================================================================
  group('generateStructuredCaption', () {
    late MockCaptionService mockCaption;
    late MockSamProcessService mockSam;
    late MockColorExtractionService mockColor;
    late MockStructuredPromptLoader mockLoader;
    late StructuredCaptionRepository repo;
    late LlmConfig config;

    /// VLM JSON with one singular object (Cat → SAM-eligible) and one group
    /// object (Books → skipped by SAM). Bboxes are VLM [x1,y1,x2,y2].
    const String vlmResponse = '''
{
  "high_level_description": "a cat near some books",
  "style": {
    "medium": "photograph",
    "aesthetics": "cozy",
    "lighting": "soft",
    "photo_or_art": "DSLR"
  },
  "background": "wooden floor",
  "objects": [
    {"name": "Cat", "desc": "a tabby cat", "type": "obj", "bbox": [100, 200, 300, 400]},
    {"name": "Books", "desc": "a stack of books", "type": "obj", "bbox": [600, 700, 800, 900]}
  ]
}''';

    setUp(() {
      mockCaption = MockCaptionService();
      mockSam = MockSamProcessService();
      mockColor = MockColorExtractionService();
      mockLoader = MockStructuredPromptLoader();
      config = LlmConfig(
        id: 'cfg',
        name: 'cfg',
        model: 'vlm',
        providerType: LlmProviderType.remote,
      );
      repo = StructuredCaptionRepository(
        captionService: mockCaption,
        samProcessService: mockSam,
        colorExtractionService: mockColor,
        promptLoader: mockLoader,
      );
      when(
        mockLoader.loadVisionAnalysisPrompt(),
      ).thenAnswer((_) async => 'PROMPT aspect={{aspect_ratio}}');
      when(
        mockCaption.getCaption(
          any,
          any,
          any,
          maxTokens: 8192,
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async => vlmResponse);
    });

    test('runs the full pipeline and emits progress for each step', () async {
      when(
        mockColor.extractPalette(any),
      ).thenAnswer((_) async => <String>['#GLOBAL']);
      // Cat bbox normalizes [x1,y1,x2,y2]=[100,200,300,400] → [200,100,400,300].
      when(
        mockSam.detectObjects(
          'img.png',
          <String>['Cat'],
          vlmBboxes: <List<int>?>[
            <int>[200, 100, 400, 300],
          ],
        ),
      ).thenAnswer(
        (_) async => <SamDetection>[
          const SamDetection(name: 'Cat', bbox: <int>[210, 110, 410, 310]),
        ],
      );
      when(
        mockColor.extractPaletteFromRegion(any, any),
      ).thenAnswer((_) async => <String>['#ELEM']);

      final List<String> steps = <String>[];
      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: steps.add,
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      // Every pipeline phase announced.
      expect(steps, contains('Extracting color palette...'));
      expect(steps, contains('Analyzing image with VLM...'));
      expect(steps, contains('Building structured caption...'));

      // Global palette lands on the style.
      expect(caption.styleDescription.colorPalette, <String>['#GLOBAL']);
      expect(caption.highLevelDescription, 'a cat near some books');

      // Both objects became elements.
      expect(caption.compositionalDeconstruction.elements, hasLength(2));
      // SAM refined the Cat; Books fell back to its VLM bbox.
      expect(caption.compositionalDeconstruction.elements[0].bbox, <int>[
        210,
        110,
        410,
        310,
      ]);
      // VLM Books bbox [600,700,800,900](x1,y1,x2,y2) → [700,600,900,800].
      expect(caption.compositionalDeconstruction.elements[1].bbox, <int>[
        700,
        600,
        900,
        800,
      ]);
    });

    test(
      'only sends singular objects to SAM (group elements skipped)',
      () async {
        when(mockColor.extractPalette(any)).thenAnswer((_) async => <String>[]);
        when(
          mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
        ).thenAnswer((_) async => <SamDetection>[]);
        when(
          mockColor.extractPaletteFromRegion(any, any),
        ).thenAnswer((_) async => <String>[]);

        await repo.generateStructuredCaption(
          config,
          File('img.png'),
          onProgress: (_) {},
        );

        // "Books" is plural → must NOT be sent to SAM; only "Cat" is.
        verify(
          mockSam.detectObjects('img.png', <String>[
            'Cat',
          ], vlmBboxes: anyNamed('vlmBboxes')),
        ).called(1);
        verifyNever(
          mockSam.detectObjects('img.png', <String>[
            'Books',
          ], vlmBboxes: anyNamed('vlmBboxes')),
        );
      },
    );

    test('skips SAM entirely when disableSam is true', () async {
      when(mockColor.extractPalette(any)).thenAnswer((_) async => <String>[]);
      when(
        mockColor.extractPaletteFromRegion(any, any),
      ).thenAnswer((_) async => <String>[]);

      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: (_) {},
                    disableSam: true,
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      verifyNever(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      );
      // Elements still built from VLM bboxes.
      expect(caption.compositionalDeconstruction.elements, hasLength(2));
    });

    test('continues with an empty palette when extraction fails', () async {
      when(mockColor.extractPalette(any)).thenThrow(Exception('decode failed'));
      when(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      ).thenAnswer((_) async => <SamDetection>[]);
      when(
        mockColor.extractPaletteFromRegion(any, any),
      ).thenAnswer((_) async => <String>[]);

      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: (_) {},
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      // Palette failure is non-fatal — pipeline still produces a caption.
      expect(caption.styleDescription.colorPalette, isEmpty);
      expect(caption.compositionalDeconstruction.elements, hasLength(2));
    });

    test('falls back to VLM bboxes when SAM detection throws', () async {
      when(mockColor.extractPalette(any)).thenAnswer((_) async => <String>[]);
      when(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      ).thenThrow(Exception('subprocess crashed'));
      when(
        mockColor.extractPaletteFromRegion(any, any),
      ).thenAnswer((_) async => <String>[]);

      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: (_) {},
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      // SAM failed → Cat element uses its VLM bbox [200,100,400,300].
      expect(caption.compositionalDeconstruction.elements[0].bbox, <int>[
        200,
        100,
        400,
        300,
      ]);
    });

    test(
      'generateStructuredCaption rethrows CancellationException, not Failure',
      () async {
        final CancelToken token = CancelToken();
        when(mockColor.extractPalette(any)).thenAnswer((_) async => <String>[]);
        when(
          mockCaption.getCaption(
            any,
            any,
            any,
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async {
          await token
              .onCancel; // park until cancelled, like a real in-flight call
          throw const CancellationException('VLM cancelled.');
        });

        final Future<Either<Failure, StructuredCaptionDocument>> result = repo
            .generateStructuredCaption(
              config,
              File('img.png'),
              onProgress: (_) {},
              cancelToken: token,
            );
        await Future<void>.delayed(
          Duration.zero,
        ); // let the run reach the VLM call
        token.cancel();

        await expectLater(result, throwsA(isA<CancellationException>()));
      },
    );
  });

  // ===========================================================================
  // multi-stage mode: enumerate (terse) → per-element enrich (rich) → merge.
  // Stubs the full collaborator set so the shared _finalizeCaption tail runs
  // end-to-end; SAM is disabled (we are testing the vision stage, not SAM).
  // ===========================================================================
  group('multi-stage mode', () {
    late MockCaptionService mockCaption;
    late MockBboxHighlightService mockBbox;
    late MockColorExtractionService mockColor;
    late MockStructuredPromptLoader mockLoader;
    late MockSamProcessService mockSam;
    late StructuredCaptionRepository repo;
    late LlmConfig config;

    const String enumerateTwoBboxes =
        '{"high_level_description":"a desk","style":{"medium":"photograph","aesthetics":"x","lighting":"y","photo_or_art":"z"},"background":"wall","objects":[{"name":"Mug","type":"obj","desc":"terse mug","bbox":[100,100,300,300]},{"name":"Book","type":"obj","desc":"terse book","bbox":[400,400,600,600]}]}';

    const String enumerateOneBbox =
        '{"high_level_description":"a desk","style":{"medium":"photograph","aesthetics":"x","lighting":"y","photo_or_art":"z"},"background":"wall","objects":[{"name":"Mug","type":"obj","desc":"terse mug","bbox":[100,100,300,300]}]}';

    const String enumerateNoBbox =
        '{"high_level_description":"a desk","style":{"medium":"photograph","aesthetics":"x","lighting":"y","photo_or_art":"z"},"background":"wall","objects":[{"name":"Blob","type":"obj","desc":"bbox-less blob"}]}';

    const String enrichRich =
        '{"desc":"a ceramic mug with glossy teal glaze and a small chip on the handle"}';

    setUp(() {
      mockCaption = MockCaptionService();
      mockBbox = MockBboxHighlightService();
      mockColor = MockColorExtractionService();
      mockLoader = MockStructuredPromptLoader();
      mockSam = MockSamProcessService();
      config = LlmConfig(
        id: 'cfg',
        name: 'cfg',
        model: 'vlm',
        providerType: LlmProviderType.remote,
      );
      repo = StructuredCaptionRepository(
        captionService: mockCaption,
        bboxHighlightService: mockBbox,
        colorExtractionService: mockColor,
        promptLoader: mockLoader,
        samProcessService: mockSam,
      );
      when(
        mockLoader.loadVisionEnumeratePrompt(),
      ).thenAnswer((_) async => 'ENUM {{aspect_ratio}} {{bbox_order}}');
      when(
        mockLoader.loadElementEnrichPrompt(),
      ).thenAnswer((_) async => 'ENRICH {name} {type}');
      when(
        mockBbox.renderCroppedJpeg(any, any),
      ).thenAnswer((_) async => '/tmp/crop.jpg');
      when(mockBbox.cleanup(any)).thenAnswer((_) async {});
      when(
        mockColor.extractPalette(any),
      ).thenAnswer((_) async => <String>['#ffffff']);
      when(
        mockColor.extractPaletteFromRegion(any, any),
      ).thenAnswer((_) async => <String>['#000000']);
      when(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      ).thenAnswer((_) async => <SamDetection>[]);
    });

    test(
      'Behavior A — enumerate then one enrich per bbox, merged desc is rich',
      () async {
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('ENUM')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async => enumerateTwoBboxes);
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('ENRICH')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async => enrichRich);

        final IdeogramCaption caption =
            ((await repo.generateStructuredCaption(
                      config,
                      File('img.png'),
                      onProgress: (_) {},
                      disableSam: true,
                      mode: StructuredMode.multiStage,
                    )).getRight().toNullable()!
                    as IdeogramDocument)
                .caption;

        final String json = caption.toJsonString();
        expect(json, contains('ceramic mug with glossy teal glaze'));
        expect(json, isNot(contains('terse mug')));
        verify(mockBbox.renderCroppedJpeg(any, any)).called(2);
      },
    );

    test(
      'Behavior B — enrich failure keeps terse desc, image still succeeds',
      () async {
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('ENUM')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async => enumerateOneBbox);
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('ENRICH')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenThrow(Exception('enrich boom'));

        final IdeogramCaption caption =
            ((await repo.generateStructuredCaption(
                      config,
                      File('img.png'),
                      onProgress: (_) {},
                      disableSam: true,
                      mode: StructuredMode.multiStage,
                    )).getRight().toNullable()!
                    as IdeogramDocument)
                .caption;

        expect(caption.toJsonString(), contains('terse mug'));
      },
    );

    test(
      'Behavior C — bbox-less object skipped by enrichment, kept terse',
      () async {
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('ENUM')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async => enumerateNoBbox);

        final IdeogramCaption caption =
            ((await repo.generateStructuredCaption(
                      config,
                      File('img.png'),
                      onProgress: (_) {},
                      disableSam: true,
                      mode: StructuredMode.multiStage,
                    )).getRight().toNullable()!
                    as IdeogramDocument)
                .caption;

        verifyNever(mockBbox.renderCroppedJpeg(any, any));
        expect(caption.toJsonString(), contains('bbox-less blob'));
        verify(
          mockCaption.getCaption(
            any,
            any,
            any,
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).called(1);
      },
    );

    test(
      'Behavior D — mixed success/failure fan-out preserves index mapping',
      () async {
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('ENUM')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer((_) async => enumerateTwoBboxes);
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('Mug')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenAnswer(
          (_) async => '{"desc":"rich mug description with ceramic glaze"}',
        );
        when(
          mockCaption.getCaption(
            any,
            any,
            argThat(contains('Book')),
            maxTokens: anyNamed('maxTokens'),
            cancelToken: anyNamed('cancelToken'),
          ),
        ).thenThrow(Exception('book enrich boom'));

        final IdeogramCaption caption =
            ((await repo.generateStructuredCaption(
                      config,
                      File('img.png'),
                      onProgress: (_) {},
                      disableSam: true,
                      mode: StructuredMode.multiStage,
                    )).getRight().toNullable()!
                    as IdeogramDocument)
                .caption;

        final String json = caption.toJsonString();
        expect(json, contains('rich mug description with ceramic glaze'));
        expect(json, contains('terse book'));
        verify(mockBbox.renderCroppedJpeg(any, any)).called(2);
      },
    );

    // Concurrency contract. Local MLX spawns a subprocess that reloads the
    // full model per call, so parallel enrich calls load multiple model
    // copies and freeze the machine. The fan-out MUST be serial for local
    // MLX and parallel for remote.
    const String enumerateFiveBboxes =
        '{"high_level_description":"a shelf","style":{"medium":"photograph",'
        '"aesthetics":"x","lighting":"y","photo_or_art":"z"},'
        '"background":"wall","objects":['
        '{"name":"O1","type":"obj","desc":"a","bbox":[10,10,100,100]},'
        '{"name":"O2","type":"obj","desc":"b","bbox":[110,110,200,200]},'
        '{"name":"O3","type":"obj","desc":"c","bbox":[210,210,300,300]},'
        '{"name":"O4","type":"obj","desc":"d","bbox":[310,310,400,400]},'
        '{"name":"O5","type":"obj","desc":"e","bbox":[410,410,500,500]}]}';

    test('local MLX enrich runs serially (max in-flight == 1)', () async {
      int current = 0;
      int maxInflight = 0;
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENUM')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async => enumerateFiveBboxes);
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENRICH')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async {
        current++;
        if (current > maxInflight) {
          maxInflight = current;
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        current--;
        return '{"desc":"rich desc"}';
      });

      final LlmConfig localConfig = LlmConfig(
        id: 'local',
        name: 'local',
        model: 'qwen3-vl-4b',
        providerType: LlmProviderType.localMlx,
      );
      await repo.generateStructuredCaption(
        localConfig,
        File('img.png'),
        onProgress: (_) {},
        disableSam: true,
        mode: StructuredMode.multiStage,
      );

      expect(maxInflight, 1);
    });

    test('remote enrich fans out in parallel (max in-flight >= 2)', () async {
      int current = 0;
      int maxInflight = 0;
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENUM')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async => enumerateFiveBboxes);
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENRICH')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async {
        current++;
        if (current > maxInflight) {
          maxInflight = current;
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        current--;
        return '{"desc":"rich desc"}';
      });

      await repo.generateStructuredCaption(
        config,
        File('img.png'),
        onProgress: (_) {},
        disableSam: true,
        mode: StructuredMode.multiStage,
      );

      expect(maxInflight, greaterThanOrEqualTo(2));
    });
  });

  // =========================================================================
  // Multi-stage quality gates
  // =========================================================================

  group('multi-stage quality gates', () {
    late MockCaptionService mockCaption;
    late MockBboxHighlightService mockBbox;
    late MockColorExtractionService mockColor;
    late MockStructuredPromptLoader mockLoader;
    late MockSamProcessService mockSam;
    late StructuredCaptionRepository repo;
    late LlmConfig config;

    setUp(() {
      mockCaption = MockCaptionService();
      mockBbox = MockBboxHighlightService();
      mockColor = MockColorExtractionService();
      mockLoader = MockStructuredPromptLoader();
      mockSam = MockSamProcessService();
      config = LlmConfig(
        id: 'cfg',
        name: 'cfg',
        model: 'vlm',
        providerType: LlmProviderType.remote,
      );
      repo = StructuredCaptionRepository(
        captionService: mockCaption,
        bboxHighlightService: mockBbox,
        colorExtractionService: mockColor,
        promptLoader: mockLoader,
        samProcessService: mockSam,
      );
      when(
        mockLoader.loadVisionEnumeratePrompt(),
      ).thenAnswer((_) async => 'ENUM {{aspect_ratio}} {{bbox_order}}');
      when(
        mockLoader.loadElementEnrichPrompt(),
      ).thenAnswer((_) async => 'ENRICH {name} {type} {desc} {bbox}');
      when(
        mockBbox.renderCroppedJpeg(any, any),
      ).thenAnswer((_) async => '/tmp/crop.jpg');
      when(mockBbox.cleanup(any)).thenAnswer((_) async {});
      when(
        mockColor.extractPalette(any),
      ).thenAnswer((_) async => <String>['#ffffff']);
      when(
        mockColor.extractPaletteFromRegion(any, any),
      ).thenAnswer((_) async => <String>['#000000']);
      when(
        mockSam.detectObjects(any, any, vlmBboxes: anyNamed('vlmBboxes')),
      ).thenAnswer((_) async => <SamDetection>[]);
    });

    const String enumerateFullCanvas =
        '{"high_level_description":"a room","style":{"medium":"photograph","aesthetics":"x","lighting":"y","photo_or_art":"z"},"background":"wall","objects":['
        '{"name":"Sofa","type":"obj","desc":"terse sofa","bbox":[0,0,1000,1000]},'
        '{"name":"Table","type":"obj","desc":"terse table","bbox":[100,100,300,300]}]}';

    test('full-canvas bbox skips enrichment, keeps terse desc', () async {
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENUM')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async => enumerateFullCanvas);
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENRICH')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            '{"desc":"a wooden table with four visible legs and a dark surface finish"}',
      );

      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: (_) {},
                    disableSam: true,
                    mode: StructuredMode.multiStage,
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      final String json = caption.toJsonString();
      expect(json, contains('terse sofa'));
      expect(json, contains('wooden table with four visible legs'));
      verify(mockBbox.renderCroppedJpeg(any, any)).called(1);
    });

    const String enumerateNearFullCanvas =
        '{"high_level_description":"a room","style":{"medium":"photograph","aesthetics":"x","lighting":"y","photo_or_art":"z"},"background":"wall","objects":['
        '{"name":"Floor","type":"obj","desc":"terse floor","bbox":[0,0,1000,900]},'
        '{"name":"Chair","type":"obj","desc":"terse chair","bbox":[200,200,400,400]}]}';

    test('near-full-canvas bbox skips enrichment, keeps terse desc', () async {
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENUM')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async => enumerateNearFullCanvas);
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENRICH')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            '{"desc":"a wooden chair with a curved backrest and four tapered legs"}',
      );

      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: (_) {},
                    disableSam: true,
                    mode: StructuredMode.multiStage,
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      final String json = caption.toJsonString();
      expect(json, contains('terse floor'));
      expect(json, contains('wooden chair with a curved backrest'));
      verify(mockBbox.renderCroppedJpeg(any, any)).called(1);
    });

    const String enumerateOneBbox =
        '{"high_level_description":"a desk","style":{"medium":"photograph","aesthetics":"x","lighting":"y","photo_or_art":"z"},"background":"wall","objects":[{"name":"Mug","type":"obj","desc":"terse mug","bbox":[100,100,300,300]}]}';

    test('enrich sanity-check rejection keeps terse desc', () async {
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENUM')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer((_) async => enumerateOneBbox);
      when(
        mockCaption.getCaption(
          any,
          any,
          argThat(contains('ENRICH')),
          maxTokens: anyNamed('maxTokens'),
          cancelToken: anyNamed('cancelToken'),
        ),
      ).thenAnswer(
        (_) async =>
            '{"desc":"This is the room with a large sofa and table in the scene"}',
      );

      final IdeogramCaption caption =
          ((await repo.generateStructuredCaption(
                    config,
                    File('img.png'),
                    onProgress: (_) {},
                    disableSam: true,
                    mode: StructuredMode.multiStage,
                  )).getRight().toNullable()!
                  as IdeogramDocument)
              .caption;

      final String json = caption.toJsonString();
      expect(json, contains('terse mug'));
    });
  });

  // =========================================================================
  // buildMossLayoutCaption — the MOSS counterpart of buildIdeogramCaption.
  // =========================================================================

  group('buildMossLayoutCaption', () {
    late StructuredCaptionRepository repo;

    setUp(() {
      repo = StructuredCaptionRepository();
    });

    const VlmAnalysis analysis = VlmAnalysis(
      highLevelDescription: 'A park scene',
      style: VlmStyle(
        medium: 'photograph',
        aesthetics: 'serene, warm',
        lighting: 'golden hour',
        photoOrArt: 'DSLR, 50mm',
      ),
      background: 'clear blue sky',
      objects: <VlmObject>[
        VlmObject(name: 'Tree', desc: 'oak tree'),
        VlmObject(name: 'Sign', desc: 'white sign', type: 'text', text: 'HI'),
      ],
    );

    test('maps style fields into summary meta and folds background in', () {
      final MossLayoutCaption caption = repo.buildMossLayoutCaption(
        <String>['#87CEEB'],
        analysis,
        const <SamDetection>[],
        const <int, List<String>>{},
        null,
        width: 1024,
        height: 1024,
      );

      expect(caption.width, 1024);
      expect(caption.height, 1024);
      expect(caption.summary.caption, 'A park scene clear blue sky');
      expect(caption.summary.meta, <String>[
        'photograph',
        'serene',
        'warm',
        'golden hour',
        'DSLR, 50mm',
      ]);
      expect(caption.summary.palette, <String>['#87CEEB']);
    });

    test('builds items with labels, tags, pixel bboxes and palettes', () {
      final List<SamDetection> detections = <SamDetection>[
        const SamDetection(name: 'Tree', bbox: <int>[0, 0, 500, 500]),
        const SamDetection(name: 'Sign', bbox: <int>[500, 500, 1000, 1000]),
      ];
      final MossLayoutCaption caption = repo.buildMossLayoutCaption(
        <String>[],
        analysis,
        detections,
        const <int, List<String>>{
          0: <String>['#2D5016'],
        },
        null,
        width: 1000,
        height: 1000,
      );

      expect(caption.items, hasLength(2));
      expect(caption.items[0].label, 'object');
      expect(caption.items[0].caption, 'oak tree');
      expect(caption.items[0].tags, <String>['Tree']);
      expect(caption.items[0].bbox, <int>[0, 0, 500, 500]);
      expect(caption.items[0].palette, <String>['#2D5016']);
      expect(caption.items[1].label, 'text');
      expect(caption.items[1].text, 'HI');
      expect(caption.items[1].bbox, <int>[500, 500, 1000, 1000]);
    });

    test('drops objects without a bbox (MOSS requires one per item)', () {
      const VlmAnalysis bboxLess = VlmAnalysis(
        highLevelDescription: 'h',
        style: VlmStyle(
          medium: 'painting',
          aesthetics: '',
          lighting: '',
          photoOrArt: '',
        ),
        background: '',
        objects: <VlmObject>[VlmObject(name: 'Ghost', desc: 'no bbox')],
      );
      final MossLayoutCaption caption = repo.buildMossLayoutCaption(
        <String>[],
        bboxLess,
        const <SamDetection>[],
        const <int, List<String>>{},
        null,
        width: 512,
        height: 512,
      );
      expect(caption.items, isEmpty);
    });

    test('applies background override into the summary caption', () {
      const StructuredBatchOverrides overrides = StructuredBatchOverrides(
        enabled: true,
        overrideBackground: true,
        background: 'stormy night',
      );
      final MossLayoutCaption caption = repo.buildMossLayoutCaption(
        <String>[],
        analysis,
        const <SamDetection>[],
        const <int, List<String>>{},
        overrides,
        width: 1024,
        height: 1024,
      );
      expect(caption.summary.caption, 'A park scene stormy night');
    });
  });
}
