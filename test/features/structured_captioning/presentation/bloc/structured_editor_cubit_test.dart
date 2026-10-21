import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/errors/failure_message.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/structured_captioning/domain/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/domain/services/layer_title_store.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/bloc/structured_editor_cubit.dart';

import 'structured_editor_cubit_test.mocks.dart';

@GenerateMocks(<Type>[IStructuredCaptionRepository])
/// Hand-rolled fake of the [CaptionFileStore] port — records caption JSON
/// written via the session and can be made to throw (disk-full simulation).
class _FakeFileStore implements CaptionFileStore {
  final List<String> writtenCaptions = <String>[];
  Object? writeError;

  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) =>
      Future<
        Either<
          Failure,
          ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
        >
      >.value(
        Right<
          Failure,
          ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
        >((
          images: <AppImage>[],
          db: CaptionDatabase(
            categories: <String>['default'],
            images: <CaptionData>[],
          ),
          dbFailure: null,
        )),
      );

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async =>
      Right<Failure, CaptionDatabase>(
        CaptionDatabase(
          categories: <String>['default'],
          images: <CaptionData>[],
        ),
      );

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
    for (final CaptionData d in db.images) {
      writtenCaptions.add(d.captions['default']?.text ?? '');
    }
  }

  @override
  Future<void> removeImage(File imageFile) async {}

  @override
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  ) async {}

  @override
  Future<void> removeCaptionFiles(
    String folderPath,
    List<AppImage> images,
  ) async {}

  @override
  Future<AppImage> duplicateImage(AppImage originalImage) async =>
      originalImage;

  @override
  int compareNatural(String a, String b) => a.compareTo(b);

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) async => images;

  @override
  Future<AppImage> getSingleImageSize(AppImage image) async => image;
}

/// Filter engine that passes images through unchanged (unfiltered sessions).
class _PassthroughFilterEngine implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => images;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  IdeogramCaption baseCaption() => const IdeogramCaption(
    highLevelDescription: 'hld',
    styleDescription: IdeogramStyleDescription(
      aesthetics: 'a',
      lighting: 'l',
      medium: 'photograph',
      colorPalette: <String>['#000000'],
    ),
    compositionalDeconstruction: IdeogramCompositionalDeconstruction(
      background: 'a plain wall',
      elements: <IdeogramElement>[
        IdeogramElement(type: 'obj', desc: 'first'),
        IdeogramElement(type: 'obj', desc: 'second'),
        IdeogramElement(type: 'obj', desc: 'third'),
      ],
    ),
  );

  provideDummy<Either<Failure, IdeogramElement>>(
    Right<Failure, IdeogramElement>(
      baseCaption().compositionalDeconstruction.elements.first,
    ),
  );
  provideDummy<Either<Failure, IdeogramStyleDescription>>(
    Right<Failure, IdeogramStyleDescription>(baseCaption().styleDescription),
  );

  provideDummy<Either<Failure, Map<int, List<int>>>>(
    const Right<Failure, Map<int, List<int>>>(<int, List<int>>{}),
  );

  provideDummy<Either<Failure, IdeogramElement>>(
    Right<Failure, IdeogramElement>(
      baseCaption().compositionalDeconstruction.elements.first,
    ),
  );
  provideDummy<Either<Failure, IdeogramStyleDescription>>(
    Right<Failure, IdeogramStyleDescription>(baseCaption().styleDescription),
  );

  provideDummy<Either<Failure, Map<int, List<int>>>>(
    const Right<Failure, Map<int, List<int>>>(<int, List<int>>{}),
  );

  group('StructuredEditorCubit', () {
    late StructuredEditorCubit cubit;
    late CaptionSessionService session;
    late _FakeFileStore store;

    setUpAll(() {
      locator.registerLazySingleton<Logger>(() => Logger('TestEditor'));
    });

    setUp(() {
      // LayerTitleStore reads/writes SharedPreferences; isolate per test.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = _FakeFileStore();
      session = CaptionSessionService(
        fileStore: store,
        filterEngine: _PassthroughFilterEngine(),
      );
      // One seeded image so session.updateCaption has a current target.
      session.adopt(
        ImageListState(
          images: <AppImage>[
            AppImage(
              id: 'img',
              image: File('img.png'),
              captions: const <String, CaptionEntry>{},
            ),
          ],
          folderPath: '/tmp',
          currentImageId: 'img',
        ),
      );
      cubit = StructuredEditorCubit(
        initialCaption: baseCaption(),
        imageFile: File('img.png'),
        activeCategory: 'default',
        session: session,
        repository: MockIStructuredCaptionRepository(),
      );
    });

    tearDown(() async {
      await cubit.flushSave();
      await cubit.close();
    });

    test('initial state holds caption and no selection', () {
      expect(cubit.state.caption.highLevelDescription, 'hld');
      expect(cubit.state.isElementSelected, false);
      expect(cubit.state.selectedElement, isNull);
    });

    group('style / description updates', () {
      test('updateHighLevelDescription mutates caption', () {
        cubit.updateHighLevelDescription('new description');
        expect(cubit.state.caption.highLevelDescription, 'new description');
      });

      test('updateAesthetics mutates style description', () {
        cubit.updateAesthetics('moody');
        expect(cubit.state.caption.styleDescription.aesthetics, 'moody');
      });

      test('updateLighting mutates style description', () {
        cubit.updateLighting('soft');
        expect(cubit.state.caption.styleDescription.lighting, 'soft');
      });

      test('updateMedium mutates style description', () {
        cubit.updateMedium('oil painting');
        expect(cubit.state.caption.styleDescription.medium, 'oil painting');
      });

      test('updateStyleColorPalette replaces palette', () {
        cubit.updateStyleColorPalette(const <String>['#ffffff', '#aaaaaa']);
        expect(cubit.state.caption.styleDescription.colorPalette, <String>[
          '#ffffff',
          '#aaaaaa',
        ]);
      });

      test('updatePhoto sets value, clearPhoto keeps it nullable', () {
        cubit.updatePhoto('50mm');
        expect(cubit.state.caption.styleDescription.photo, '50mm');
        cubit.updatePhoto(null);
        expect(cubit.state.caption.styleDescription.photo, isNull);
      });
    });

    group('element selection', () {
      test('selectElement sets index and resolves selectedElement', () {
        cubit.selectElement(1);
        expect(cubit.state.selectedElementIndex, 1);
        expect(cubit.state.selectedElement?.desc, 'second');
      });

      test('selectElement ignores out-of-range index', () {
        cubit.selectElement(99);
        expect(cubit.state.selectedElementIndex, isNull);
      });

      test('deselectElement clears selection', () {
        cubit.selectElement(0);
        cubit.deselectElement();
        expect(cubit.state.selectedElementIndex, isNull);
      });
    });

    group('element editing (requires selection)', () {
      test('updateElementDesc writes to selected element only', () {
        cubit.selectElement(0);
        cubit.updateElementDesc('edited first');
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[0].desc,
          'edited first',
        );
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].desc,
          'second',
        );
      });

      test('updateElementType changes type', () {
        cubit.selectElement(2);
        cubit.updateElementType('text');
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[2].type,
          'text',
        );
      });

      test('updateElementBbox sets then clears', () {
        cubit.selectElement(1);
        cubit.updateElementBbox(const <int>[10, 20, 30, 40]);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].bbox,
          <int>[10, 20, 30, 40],
        );
        cubit.updateElementBbox(null);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].bbox,
          isNull,
        );
      });

      test('editors are no-ops without selection', () {
        cubit.updateElementDesc('noop');
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[0].desc,
          'first',
        );
      });
    });

    group('element CRUD', () {
      test('addElement appends and selects the new element', () {
        cubit.addElement();
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          4,
        );
        expect(cubit.state.selectedElementIndex, 3);
      });

      test('removeElement removes the element', () {
        cubit.removeElement(1);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          2,
        );
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].desc,
          'third',
        );
      });

      test('removeElement deselects when removing the selected element', () {
        cubit.selectElement(1);
        cubit.removeElement(1);
        expect(cubit.state.selectedElementIndex, isNull);
      });

      test(
        'removeElement shifts selection down when removing earlier element',
        () {
          cubit.selectElement(2);
          cubit.removeElement(0);
          expect(cubit.state.selectedElementIndex, 1);
        },
      );

      test('removeElement shifts hidden indices', () {
        cubit.toggleElementVisibility(2);
        expect(cubit.state.hiddenElementIndices, <int>{2});
        cubit.removeElement(0);
        expect(cubit.state.hiddenElementIndices, <int>{1});
      });

      test('removeElement ignores out-of-range index', () {
        cubit.removeElement(99);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          3,
        );
      });
    });

    group('visibility', () {
      test('toggleElementVisibility adds then removes index', () {
        cubit.toggleElementVisibility(0);
        expect(cubit.state.hiddenElementIndices, <int>{0});
        cubit.toggleElementVisibility(0);
        expect(cubit.state.hiddenElementIndices, <int>{});
      });
    });

    group('layer titles (UI-only)', () {
      test('setElementTitle sets, trims, and clears', () {
        cubit.setElementTitle(1, '  hero  ');
        expect(cubit.state.elementTitles, <int, String>{1: 'hero'});
        // Clearing via empty string removes it.
        cubit.setElementTitle(1, '   ');
        expect(cubit.state.elementTitles, <int, String>{});
      });

      test(
        'setElementTitle persists titles WITHOUT touching the caption JSON',
        () async {
          cubit.setElementTitle(1, 'hero');
          await cubit.flushSave();

          // Caption JSON is never rewritten for a title-only change.
          expect(store.writtenCaptions, isEmpty);
          // Titles round-trip through the sidecar store.
          expect(await const LayerTitleStore().load('img.png'), <int, String>{
            1: 'hero',
          });
        },
      );

      test('persisted titles are restored on cubit construction', () async {
        await const LayerTitleStore().save('seeded.png', <int, String>{
          0: 'restored',
          2: 'bg',
        });
        final StructuredEditorCubit c = StructuredEditorCubit(
          initialCaption: baseCaption(),
          imageFile: File('seeded.png'),
          activeCategory: 'default',
          session: session,
          repository: MockIStructuredCaptionRepository(),
        );
        // Let the constructor's fire-and-forget _loadTitles() land.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(c.state.elementTitles, <int, String>{0: 'restored', 2: 'bg'});
        await c.flushSave();
        await c.close();
      });
    });

    group('reorder (moveElement)', () {
      test(
        'moves element and remaps selection, hidden, and titles together',
        () {
          // Setup: titles on 0, hidden 2, selection 0.
          cubit.setElementTitle(0, 'first-title');
          cubit.toggleElementVisibility(2);
          cubit.selectElement(0);

          // Move element at index 0 ('first') to index 2.
          cubit.moveElement(0, 2);

          final List<IdeogramElement> els =
              cubit.state.caption.compositionalDeconstruction.elements;
          // JSON reordered: ['second', 'third', 'first'].
          expect(els.map((IdeogramElement e) => e.desc).toList(), <String>[
            'second',
            'third',
            'first',
          ]);
          // Title followed the element (old 0 -> new 2).
          expect(cubit.state.elementTitles, <int, String>{2: 'first-title'});
          // Hidden 'third' shifted old 2 -> new 1.
          expect(cubit.state.hiddenElementIndices, <int>{1});
          // Selection followed old 0 -> new 2.
          expect(cubit.state.selectedElementIndex, 2);
        },
      );

      test('moveElement(from == to) is a no-op', () {
        cubit.moveElement(1, 1);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements
              .map((IdeogramElement e) => e.desc)
              .toList(),
          <String>['first', 'second', 'third'],
        );
      });

      test('moveElement ignores out-of-range indices', () {
        cubit.moveElement(-1, 0);
        cubit.moveElement(0, 99);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          3,
        );
      });

      test('moveElement schedules a save', () async {
        cubit.moveElement(0, 2);
        await cubit.flushSave();
        expect(store.writtenCaptions, hasLength(1));
      });
    });

    group('save', () {
      test('flushSave persists caption and emits saved status', () async {
        cubit.updateHighLevelDescription('dirty');
        await cubit.flushSave();

        expect(cubit.state.status, StructuredEditorStatus.saved);
        expect(store.writtenCaptions, hasLength(1));
        expect(store.writtenCaptions.single, contains('dirty'));
      });

      test('save emits error status when the caption write throws', () async {
        store.writeError = const FileSystemException(
          'disk full',
          '/private/var/folders/db.json',
        );

        cubit.updateHighLevelDescription('dirty again');
        await cubit.flushSave();

        expect(cubit.state.status, StructuredEditorStatus.error);
        expect(cubit.state.error, failureMessage(const Failure.io()));
        expect(
          cubit.state.error,
          isNot(contains('/private/var/folders/db.json')),
        );

        // Clear the fault and flush so the pending (failed) save doesn't
        // re-fire during tearDown's close.
        store.writeError = null;
        await cubit.flushSave();
      });

      test('flushSave is a no-op when nothing changed', () async {
        await cubit.flushSave();
        expect(store.writtenCaptions, isEmpty);
      });
    });

    group('recaptionSelectedElement', () {
      late MockIStructuredCaptionRepository mockRepo;
      late Completer<Either<Failure, IdeogramElement>> recaptionCompleter;

      IdeogramCaption withSelection({required bool withBbox}) =>
          baseCaption().copyWith(
            compositionalDeconstruction: baseCaption()
                .compositionalDeconstruction
                .copyWith(
                  elements: <IdeogramElement>[
                    IdeogramElement(
                      type: 'obj',
                      desc: 'first',
                      bbox: withBbox ? <int>[10, 10, 90, 90] : null,
                    ),
                    const IdeogramElement(type: 'obj', desc: 'second'),
                  ],
                ),
          );

      setUp(() {
        mockRepo = MockIStructuredCaptionRepository();
        recaptionCompleter = Completer<Either<Failure, IdeogramElement>>();
      });

      StructuredEditorCubit buildCubit({required bool withBbox}) {
        final StructuredEditorCubit c = StructuredEditorCubit(
          initialCaption: withSelection(withBbox: withBbox),
          imageFile: File('img.png'),
          activeCategory: 'default',
          session: session,
          repository: mockRepo,
        );
        c.selectElement(0);
        return c;
      }

      test('no-ops when no element is selected', () async {
        final StructuredEditorCubit c = StructuredEditorCubit(
          initialCaption: baseCaption(),
          imageFile: File('img.png'),
          activeCategory: 'default',
          session: session,
          repository: mockRepo,
        );
        await c.recaptionSelectedElement(config: _dummyConfig());
        expect(c.state.status, isNot(StructuredEditorStatus.recaptioning));
        verifyNever(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        );
        await c.flushSave();
        await c.close();
      });

      test('emits error when selected element has no bbox', () async {
        final StructuredEditorCubit c = buildCubit(withBbox: false);
        when(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).thenThrow(
          StateError('Target element has no bbox; cannot highlight.'),
        );

        await c.recaptionSelectedElement(config: _dummyConfig());

        expect(c.state.status, StructuredEditorStatus.error);
        expect(c.state.error, failureMessage(const Failure.unexpected()));
        expect(c.state.error, isNot(contains('bbox')));
        expect(
          c.state.caption.compositionalDeconstruction.elements[0].desc,
          'first',
        );
        await c.flushSave();
        await c.close();
      });

      test('recaptioning status then element update on success', () async {
        final StructuredEditorCubit c = buildCubit(withBbox: true);
        final Completer<Either<Failure, IdeogramElement>> completer =
            Completer<Either<Failure, IdeogramElement>>();

        when(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).thenAnswer((_) => completer.future);

        // Kick off; don't await — the mock is genuinely suspended.
        final Future<void> done = c.recaptionSelectedElement(
          config: _dummyConfig(),
          instructions: 'focus on branding',
        );
        // Let the pre-call emits settle.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(c.state.status, StructuredEditorStatus.recaptioning);
        expect(c.state.recaptioningElementIndex, 0);

        // Complete the suspended VLM call.
        completer.complete(
          Right<Failure, IdeogramElement>(
            c.state.caption.compositionalDeconstruction.elements[0].copyWith(
              desc: 'fresh',
            ),
          ),
        );
        await done;

        expect(
          c.state.caption.compositionalDeconstruction.elements[0].desc,
          'fresh',
        );
        expect(c.state.recaptioningElementIndex, isNull);
        await c.flushSave();
        await c.close();
      });

      test('original element byte-identical on repo error', () async {
        final StructuredEditorCubit c = buildCubit(withBbox: true);
        final IdeogramElement original =
            c.state.caption.compositionalDeconstruction.elements[0];
        when(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).thenThrow(Exception('boom'));

        await c.recaptionSelectedElement(config: _dummyConfig());

        expect(c.state.status, StructuredEditorStatus.error);
        final IdeogramElement after =
            c.state.caption.compositionalDeconstruction.elements[0];
        expect(after, original);
        await c.flushSave();
        await c.close();
      });

      test('concurrent call is a no-op while one is in flight', () async {
        final StructuredEditorCubit c = buildCubit(withBbox: true);
        when(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).thenAnswer((_) => recaptionCompleter.future);

        final Future<void> first = c.recaptionSelectedElement(
          config: _dummyConfig(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));

        await c.recaptionSelectedElement(config: _dummyConfig());

        verify(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).called(1);

        recaptionCompleter.complete(
          Right<Failure, IdeogramElement>(
            c.state.caption.compositionalDeconstruction.elements[0].copyWith(
              desc: 'done',
            ),
          ),
        );
        await first;
        await c.flushSave();
        await c.close();
      });

      test('flushSave awaits an in-flight recaption before saving', () async {
        final StructuredEditorCubit c = buildCubit(withBbox: true);
        final Completer<Either<Failure, IdeogramElement>> completer =
            Completer<Either<Failure, IdeogramElement>>();

        when(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).thenAnswer((_) => completer.future);

        final Future<void> recaptionFuture = c.recaptionSelectedElement(
          config: _dummyConfig(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));

        bool flushDone = false;
        final Future<void> flush = c.flushSave().then((_) {
          flushDone = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(
          flushDone,
          isFalse,
          reason: 'flushSave must wait for the in-flight recaption',
        );

        completer.complete(
          Right<Failure, IdeogramElement>(
            c.state.caption.compositionalDeconstruction.elements[0].copyWith(
              desc: 'done',
            ),
          ),
        );
        await recaptionFuture;
        await flush;
        expect(flushDone, isTrue);

        await c.flushSave();
        await c.close();
      });

      test('close during in-flight recaption drops post-await emits', () async {
        final StructuredEditorCubit c = buildCubit(withBbox: true);
        final Completer<Either<Failure, IdeogramElement>> completer =
            Completer<Either<Failure, IdeogramElement>>();

        when(
          mockRepo.recaptionElement(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
            elementIndex: anyNamed('elementIndex'),
            instructions: anyNamed('instructions'),
          ),
        ).thenAnswer((_) => completer.future);

        final Future<void> done = c.recaptionSelectedElement(
          config: _dummyConfig(),
          instructions: 'brighter',
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(c.state.status, StructuredEditorStatus.recaptioning);

        // Close while the VLM call is still suspended, then let it land.
        await c.close();
        completer.complete(
          Right<Failure, IdeogramElement>(
            c.state.caption.compositionalDeconstruction.elements[0].copyWith(
              desc: 'late',
            ),
          ),
        );
        await done;
      });
    });

    group('recaptionStyle', () {
      late MockIStructuredCaptionRepository mockRepo;

      setUp(() {
        mockRepo = MockIStructuredCaptionRepository();
      });

      StructuredEditorCubit buildCubit() {
        final StructuredEditorCubit c = StructuredEditorCubit(
          initialCaption: baseCaption(),
          imageFile: File('img.png'),
          activeCategory: 'default',
          session: session,
          repository: mockRepo,
        );
        return c;
      }

      test(
        'recaptioningStyle true while in flight, style swapped on success',
        () async {
          final StructuredEditorCubit c = buildCubit();
          final Completer<Either<Failure, IdeogramStyleDescription>> completer =
              Completer<Either<Failure, IdeogramStyleDescription>>();

          when(
            mockRepo.recaptionStyle(
              config: anyNamed('config'),
              imageFile: anyNamed('imageFile'),
              currentCaption: anyNamed('currentCaption'),
            ),
          ).thenAnswer((_) => completer.future);

          final Future<void> done = c.recaptionStyle(config: _dummyConfig());
          await Future<void>.delayed(const Duration(milliseconds: 5));
          expect(c.state.status, StructuredEditorStatus.recaptioning);
          expect(c.state.recaptioningStyle, isTrue);

          completer.complete(
            const Right<Failure, IdeogramStyleDescription>(
              IdeogramStyleDescription(
                aesthetics: 'fresh-aesthetics',
                lighting: 'fresh-lighting',
                medium: 'painting',
                artStyle: 'oil',
                colorPalette: <String>['#000000'],
              ),
            ),
          );
          await done;

          expect(
            c.state.caption.styleDescription.aesthetics,
            'fresh-aesthetics',
          );
          expect(c.state.caption.styleDescription.medium, 'painting');
          expect(c.state.caption.styleDescription.artStyle, 'oil');
          expect(c.state.recaptioningStyle, isFalse);
          await c.flushSave();
          await c.close();
        },
      );

      test('original style byte-identical on repo error', () async {
        final StructuredEditorCubit c = buildCubit();
        final IdeogramStyleDescription original =
            c.state.caption.styleDescription;
        when(
          mockRepo.recaptionStyle(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
          ),
        ).thenThrow(Exception('boom'));

        await c.recaptionStyle(config: _dummyConfig());

        expect(c.state.status, StructuredEditorStatus.error);
        expect(c.state.caption.styleDescription, original);
        expect(c.state.recaptioningStyle, isFalse);
        await c.flushSave();
        await c.close();
      });

      test('concurrent call is a no-op while one is in flight', () async {
        final StructuredEditorCubit c = buildCubit();
        final Completer<Either<Failure, IdeogramStyleDescription>> completer =
            Completer<Either<Failure, IdeogramStyleDescription>>();
        when(
          mockRepo.recaptionStyle(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
          ),
        ).thenAnswer((_) => completer.future);

        final Future<void> first = c.recaptionStyle(config: _dummyConfig());
        await Future<void>.delayed(const Duration(milliseconds: 5));

        await c.recaptionStyle(config: _dummyConfig());

        verify(
          mockRepo.recaptionStyle(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
          ),
        ).called(1);

        completer.complete(
          Right<Failure, IdeogramStyleDescription>(
            baseCaption().styleDescription.copyWith(aesthetics: 'done'),
          ),
        );
        await first;
        await c.flushSave();
        await c.close();
      });

      test('flushSave awaits an in-flight style recaption', () async {
        final StructuredEditorCubit c = buildCubit();
        final Completer<Either<Failure, IdeogramStyleDescription>> completer =
            Completer<Either<Failure, IdeogramStyleDescription>>();
        when(
          mockRepo.recaptionStyle(
            config: anyNamed('config'),
            imageFile: anyNamed('imageFile'),
            currentCaption: anyNamed('currentCaption'),
          ),
        ).thenAnswer((_) => completer.future);

        final Future<void> recaptionFuture = c.recaptionStyle(
          config: _dummyConfig(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));

        bool flushDone = false;
        final Future<void> flush = c.flushSave().then((_) {
          flushDone = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(
          flushDone,
          isFalse,
          reason: 'flushSave must wait for the in-flight style recaption',
        );

        completer.complete(
          Right<Failure, IdeogramStyleDescription>(
            baseCaption().styleDescription.copyWith(aesthetics: 'done'),
          ),
        );
        await recaptionFuture;
        await flush;
        expect(flushDone, isTrue);
        await c.close();
      });
    });

    group('toggleSamBboxes', () {
      late MockIStructuredCaptionRepository mockRepo;

      IdeogramCaption captionWithBboxes() => const IdeogramCaption(
        highLevelDescription: 'hld',
        styleDescription: IdeogramStyleDescription(
          aesthetics: 'a',
          lighting: 'l',
          medium: 'photograph',
          colorPalette: <String>['#000000'],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: 'bg',
          elements: <IdeogramElement>[
            IdeogramElement(
              type: 'obj',
              desc: 'cat',
              bbox: <int>[100, 100, 200, 200],
            ),
            IdeogramElement(
              type: 'obj',
              desc: 'dog',
              bbox: <int>[300, 300, 400, 400],
            ),
          ],
        ),
      );

      setUp(() {
        mockRepo = MockIStructuredCaptionRepository();
      });

      StructuredEditorCubit buildCubit() {
        final StructuredEditorCubit c = StructuredEditorCubit(
          initialCaption: captionWithBboxes(),
          imageFile: File('img.png'),
          activeCategory: 'default',
          session: session,
          repository: mockRepo,
        );
        return c;
      }

      test('toggle ON computes SAM bboxes and flips showSamBboxes', () async {
        when(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).thenAnswer(
          (_) async =>
              const Right<Failure, Map<int, List<int>>>(<int, List<int>>{
                0: <int>[110, 110, 210, 210],
              }),
        );

        final StructuredEditorCubit c = buildCubit();
        await c.toggleSamBboxes();

        expect(c.state.showSamBboxes, isTrue);
        expect(c.state.samComputeStatus, SamComputeStatus.ready);
        expect(c.state.samBboxByIndex, <int, List<int>>{
          0: <int>[110, 110, 210, 210],
        });

        await c.flushSave();
        await c.close();
      });

      test('toggle OFF after ON does not recompute', () async {
        when(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).thenAnswer(
          (_) async =>
              const Right<Failure, Map<int, List<int>>>(<int, List<int>>{
                0: <int>[110, 110, 210, 210],
              }),
        );

        final StructuredEditorCubit c = buildCubit();
        await c.toggleSamBboxes(); // ON
        await c.toggleSamBboxes(); // OFF

        expect(c.state.showSamBboxes, isFalse);
        // Still cached.
        expect(c.state.samBboxByIndex, isNotNull);
        // Repo only called once.
        verify(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).called(1);

        await c.flushSave();
        await c.close();
      });

      test('emits computing status while awaiting', () async {
        final Completer<Either<Failure, Map<int, List<int>>>> completer =
            Completer<Either<Failure, Map<int, List<int>>>>();
        when(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).thenAnswer((_) => completer.future);

        final StructuredEditorCubit c = buildCubit();
        final Future<void> done = c.toggleSamBboxes();
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(c.state.samComputeStatus, SamComputeStatus.computing);

        completer.complete(
          const Right<Failure, Map<int, List<int>>>(<int, List<int>>{
            0: <int>[110, 110, 210, 210],
          }),
        );
        await done;

        expect(c.state.samComputeStatus, SamComputeStatus.ready);

        await c.flushSave();
        await c.close();
      });

      test('on error sets error status and leaves cache null', () async {
        when(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).thenAnswer(
          (_) async => const Left<Failure, Map<int, List<int>>>(
            Failure.unexpected(message: 'sam boom'),
          ),
        );

        final StructuredEditorCubit c = buildCubit();
        await c.toggleSamBboxes();

        expect(c.state.samComputeStatus, SamComputeStatus.error);
        expect(c.state.samBboxByIndex, isNull);
        expect(c.state.showSamBboxes, isFalse);
        expect(c.state.error, failureMessage(const Failure.unexpected()));
        expect(c.state.error, isNot(contains('sam boom')));

        await c.flushSave();
        await c.close();
      });

      test('concurrent toggles share a single in-flight call', () async {
        final Completer<Either<Failure, Map<int, List<int>>>> completer =
            Completer<Either<Failure, Map<int, List<int>>>>();
        when(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).thenAnswer((_) => completer.future);

        final StructuredEditorCubit c = buildCubit();
        final Future<void> a = c.toggleSamBboxes();
        final Future<void> b = c.toggleSamBboxes(); // should no-op silently
        await Future<void>.delayed(const Duration(milliseconds: 5));

        completer.complete(
          const Right<Failure, Map<int, List<int>>>(<int, List<int>>{
            0: <int>[110, 110, 210, 210],
          }),
        );
        await Future.wait<void>(<Future<void>>[a, b]);

        verify(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).called(1);

        await c.flushSave();
        await c.close();
      });

      test(
        'flushSave waits for in-flight SAM compute before returning',
        () async {
          final Completer<Either<Failure, Map<int, List<int>>>>
          computeCompleter = Completer<Either<Failure, Map<int, List<int>>>>();
          when(
            mockRepo.computeSamBboxes(
              imageFile: anyNamed('imageFile'),
              caption: anyNamed('caption'),
            ),
          ).thenAnswer((_) => computeCompleter.future);

          final StructuredEditorCubit c = buildCubit();
          // Start a toggle (compute is held). Don't await.
          final Future<void> toggleFuture = c.toggleSamBboxes();
          await Future<void>.delayed(const Duration(milliseconds: 5));
          expect(c.state.samComputeStatus, SamComputeStatus.computing);

          // Start flushSave — it must block until compute resolves.
          final Completer<void> flushCompleter = Completer<void>();
          c.flushSave().then((_) => flushCompleter.complete());

          // Give flushSave a chance to (wrongly) complete.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(
            flushCompleter.isCompleted,
            isFalse,
            reason: 'flushSave must wait for the in-flight SAM compute',
          );

          // Release the compute.
          computeCompleter.complete(
            const Right<Failure, Map<int, List<int>>>(<int, List<int>>{
              0: <int>[110, 110, 210, 210],
            }),
          );
          await Future.wait<void>(<Future<void>>[
            toggleFuture,
            flushCompleter.future,
          ]);

          // Compute landed safely; cubit still usable.
          expect(c.state.samComputeStatus, SamComputeStatus.ready);

          await c.close();
        },
      );
    });

    group('SAM cache invalidation', () {
      late MockIStructuredCaptionRepository mockRepo;

      setUp(() {
        mockRepo = MockIStructuredCaptionRepository();
      });

      test('editing the selected element clears the SAM cache', () async {
        when(
          mockRepo.computeSamBboxes(
            imageFile: anyNamed('imageFile'),
            caption: anyNamed('caption'),
          ),
        ).thenAnswer(
          (_) async =>
              const Right<Failure, Map<int, List<int>>>(<int, List<int>>{
                0: <int>[110, 110, 210, 210],
              }),
        );

        final StructuredEditorCubit c = StructuredEditorCubit(
          initialCaption: const IdeogramCaption(
            highLevelDescription: 'hld',
            styleDescription: IdeogramStyleDescription(
              aesthetics: 'a',
              lighting: 'l',
              medium: 'photograph',
              colorPalette: <String>['#000000'],
            ),
            compositionalDeconstruction: IdeogramCompositionalDeconstruction(
              background: 'bg',
              elements: <IdeogramElement>[
                IdeogramElement(
                  type: 'obj',
                  desc: 'cat',
                  bbox: <int>[100, 100, 200, 200],
                ),
              ],
            ),
          ),
          imageFile: File('img.png'),
          activeCategory: 'default',
          session: session,
          repository: mockRepo,
        );

        await c.toggleSamBboxes();
        expect(c.state.samBboxByIndex, isNotNull);

        c.selectElement(0);
        c.updateElementDesc('a tougher cat');

        expect(c.state.samBboxByIndex, isNull);
        expect(c.state.showSamBboxes, isFalse);
        expect(c.state.samComputeStatus, SamComputeStatus.idle);

        await c.flushSave();
        await c.close();
      });
    });
  });
}

LlmConfig _dummyConfig() => LlmConfig(
  id: 'cfg',
  name: 'cfg',
  model: 'vlm',
  providerType: LlmProviderType.remote,
);
