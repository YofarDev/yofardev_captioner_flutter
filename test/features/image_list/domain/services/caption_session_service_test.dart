import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/domain/models/image_list_state.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_snapshot.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/filter_parser_engine.dart';

/// Hand-rolled fake of the [CaptionFileStore] port — the service tests assert
/// session behavior, so the store is configurable and records writes.
class _FakeFileStore implements CaptionFileStore {
  Future<List<AppImage>> Function(String folderPath)? listImagesOverride;
  CaptionDatabase Function(String folderPath)? readDbOverride;
  final List<CaptionDatabase> writtenDbs = <CaptionDatabase>[];
  int listImagesCalls = 0;
  int removedImageFiles = 0;
  int duplicateCalls = 0;

  @override
  Future<List<AppImage>> onFolderPicked(String folderPath) {
    listImagesCalls++;
    return listImagesOverride?.call(folderPath) ??
        Future<List<AppImage>>.value(<AppImage>[]);
  }

  @override
  Future<CaptionDatabase> readDb(String folderPath) async =>
      readDbOverride?.call(folderPath) ??
      CaptionDatabase(categories: <String>['default'], images: <CaptionData>[]);

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {
    writtenDbs.add(db);
  }

  @override
  Future<void> removeImage(File imageFile) async {
    removedImageFiles++;
  }

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
  Future<AppImage> duplicateImage(AppImage originalImage) async {
    duplicateCalls++;
    return originalImage.copyWith(id: 'duplicated-id');
  }

  @override
  int compareNatural(String a, String b) => a.compareTo(b);

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) async => images;

  @override
  Future<AppImage> getSingleImageSize(AppImage image) async => image;
}

AppImage makeImage({
  required String id,
  required String path,
  int size = 100,
  int width = -1,
  int height = -1,
  Map<String, CaptionEntry>? captions,
  List<String> tags = const <String>[],
}) {
  return AppImage(
    id: id,
    image: File(path),
    captions: captions ?? const <String, CaptionEntry>{},
    size: size,
    width: width,
    height: height,
    tags: tags,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFileStore store;
  late CaptionSessionService session;

  setUp(() {
    store = _FakeFileStore();
    session = CaptionSessionService(
      fileStore: store,
      filterEngine: const FilterParserCaptionEngine(),
    );
  });

  /// Seeds the session state the same way the owning cubit does when tests
  /// set cubit state directly (adopt, no snapshot emitted).
  void seed(ImageListState state) => session.adopt(state);

  /// Collects snapshots emitted by [body] (synchronously reachable ones).
  Future<List<CaptionSessionSnapshot>> collectSnapshots(
    Future<void> Function() body,
  ) async {
    final List<CaptionSessionSnapshot> snapshots = <CaptionSessionSnapshot>[];
    void listener(CaptionSessionSnapshot s) => snapshots.add(s);
    session.addListener(listener);
    await body();
    session.removeListener(listener);
    return snapshots;
  }

  group('CaptionSessionService folder lifecycle', () {
    final AppImage testImage = makeImage(id: 't', path: '/x/test.jpg');

    test('onFolderPicked loads images when folder changes', () async {
      store.listImagesOverride = (_) async => <AppImage>[testImage];
      store.readDbOverride = (_) => CaptionDatabase(
        categories: <String>['default'],
        images: <CaptionData>[],
      );

      final List<CaptionSessionSnapshot> snapshots = await collectSnapshots(
        () => session.onFolderPicked('/new/path'),
      );

      expect(snapshots, hasLength(2));
      expect(snapshots[0].state.folderPath, '/new/path');
      expect(snapshots[0].state.images, isEmpty);
      expect(snapshots[1].state.images, hasLength(1));
      expect(store.listImagesCalls, 1);
    });

    test(
      'onFolderPicked does nothing when folder is same and not forced',
      () async {
        seed(const ImageListState(folderPath: '/existing/path'));

        final List<CaptionSessionSnapshot> snapshots = await collectSnapshots(
          () => session.onFolderPicked('/existing/path'),
        );

        expect(snapshots, isEmpty);
        expect(store.listImagesCalls, 0);
      },
    );

    test(
      'onFolderPicked reloads when folder is same AND force is true',
      () async {
        store.listImagesOverride = (_) async => <AppImage>[testImage];
        store.readDbOverride = (_) => CaptionDatabase(
          categories: <String>['default'],
          images: <CaptionData>[],
        );
        seed(
          ImageListState(
            folderPath: '/existing/path',
            images: <AppImage>[testImage],
          ),
        );

        final List<CaptionSessionSnapshot> snapshots = await collectSnapshots(
          () => session.onFolderPicked('/existing/path', force: true),
        );

        expect(snapshots, hasLength(2));
        expect(snapshots[0].state.images, isEmpty);
        expect(snapshots[1].state.images, hasLength(1));
      },
    );

    test('onFolderPicked clears state when folder cannot be loaded', () async {
      store.listImagesOverride = (_) => throw StateError('gone');
      store.readDbOverride = (_) => throw StateError('gone');
      seed(ImageListState(images: <AppImage>[testImage]));

      await session.onFolderPicked('/broken');

      expect(session.current.state.images, isEmpty);
      expect(session.current.state.folderPath, isNull);
    });

    test('onBeforeFolderLoad hook fires before reloads', () async {
      int hookCalls = 0;
      final CaptionSessionService hooked = CaptionSessionService(
        fileStore: store,
        filterEngine: const FilterParserCaptionEngine(),
        onBeforeFolderLoad: () => hookCalls++,
      );
      await hooked.onFolderPicked('/a');
      expect(hookCalls, 1);
    });

    test('removeImage removes from list, saves and deletes the file', () async {
      seed(ImageListState(images: <AppImage>[testImage], folderPath: '/x'));

      await session.removeImage(testImage.id);

      expect(session.current.state.images, isEmpty);
      expect(store.writtenDbs, hasLength(1));
      expect(store.removedImageFiles, 1);
    });

    test('duplicateImage adds duplicated image and selects it', () async {
      seed(
        ImageListState(folderPath: '/test/path', images: <AppImage>[testImage]),
      );

      await session.duplicateImage();

      expect(session.current.state.images, hasLength(2));
      expect(session.current.state.currentImageId, 'duplicated-id');
      expect(store.writtenDbs, hasLength(1));
    });

    test('duplicateImage does nothing when images list is empty', () async {
      seed(const ImageListState());

      await session.duplicateImage();

      expect(store.duplicateCalls, 0);
    });
  });

  group('CaptionSessionService navigation', () {
    late List<AppImage> threeImages;

    setUp(() {
      threeImages = <AppImage>[
        makeImage(id: 'a', path: '/folder/a.jpg'),
        makeImage(id: 'b', path: '/folder/b.jpg'),
        makeImage(id: 'c', path: '/folder/c.jpg'),
      ];
    });

    test('nextImage advances to next image', () {
      seed(ImageListState(images: threeImages, currentImageId: 'a'));
      session.nextImage();
      expect(session.current.state.currentImageId, 'b');
    });

    test('nextImage wraps from last to first', () {
      seed(ImageListState(images: threeImages, currentImageId: 'c'));
      session.nextImage();
      expect(session.current.state.currentImageId, 'a');
    });

    test('nextImage does nothing when images empty', () {
      seed(const ImageListState());
      session.nextImage();
      expect(session.current.state.currentImageId, isNull);
    });

    test('previousImage goes to previous image', () {
      seed(ImageListState(images: threeImages, currentImageId: 'c'));
      session.previousImage();
      expect(session.current.state.currentImageId, 'b');
    });

    test('previousImage wraps from first to last', () {
      seed(ImageListState(images: threeImages, currentImageId: 'a'));
      session.previousImage();
      expect(session.current.state.currentImageId, 'c');
    });

    test('previousImage does nothing when images empty', () {
      seed(const ImageListState());
      session.previousImage();
      expect(session.current.state.currentImageId, isNull);
    });

    test('currentDisplayedImage resolves selection and fallback', () {
      seed(const ImageListState());
      expect(session.current.currentDisplayedImage, isNull);

      seed(ImageListState(images: threeImages));
      expect(session.current.currentDisplayedImage?.id, 'a');

      seed(ImageListState(images: threeImages, currentImageId: 'b'));
      expect(session.current.currentDisplayedImage?.id, 'b');
    });
  });

  group('CaptionSessionService search', () {
    test('filteredImages returns all images when no search query', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(id: 'a', path: '/f/a.jpg'),
            makeImage(id: 'b', path: '/f/b.jpg'),
          ],
        ),
      );
      expect(session.current.filteredImages, hasLength(2));
    });

    test('filteredImages filters by caption text case-insensitive', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(
              id: 'a',
              path: '/f/a.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'a Cat sitting'),
              },
            ),
            makeImage(
              id: 'b',
              path: '/f/b.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'a Dog running'),
              },
            ),
          ],
          searchQuery: 'cat',
        ),
      );
      final List<AppImage> filtered = session.current.filteredImages;
      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'a');
    });

    test('filteredImages respects caseSensitive flag', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(
              id: 'a',
              path: '/f/a.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'Cat sitting'),
              },
            ),
            makeImage(
              id: 'b',
              path: '/f/b.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'cat sitting'),
              },
            ),
          ],
          searchQuery: 'Cat',
          caseSensitive: true,
        ),
      );
      final List<AppImage> filtered = session.current.filteredImages;
      expect(filtered, hasLength(1));
      expect(filtered.first.id, 'a');
    });

    test('updateSearchQuery sets query and resets to first image', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(id: 'a', path: '/f/a.jpg'),
            makeImage(id: 'b', path: '/f/b.jpg'),
          ],
          currentImageId: 'b',
        ),
      );

      session.updateSearchQuery('cat');

      expect(session.current.state.searchQuery, 'cat');
      expect(session.current.state.currentImageId, 'a');
    });

    test('toggleCaseSensitive flips the flag', () {
      seed(const ImageListState());
      session.toggleCaseSensitive();
      expect(session.current.state.caseSensitive, isTrue);
      session.toggleCaseSensitive();
      expect(session.current.state.caseSensitive, isFalse);
    });

    test('clearSearch resets query and caseSensitive', () {
      seed(const ImageListState(searchQuery: 'cat', caseSensitive: true));

      session.clearSearch();

      expect(session.current.state.searchQuery, '');
      expect(session.current.state.caseSensitive, isFalse);
    });

    test('countOccurrences counts matches and collects filenames', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(
              id: 'a',
              path: '/folder/a.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'cat dog cat'),
              },
            ),
            makeImage(
              id: 'b',
              path: '/folder/b.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'bird fish'),
              },
            ),
          ],
        ),
      );

      session.countOccurrences('cat');

      expect(session.current.state.occurrencesCount, 2);
      expect(session.current.state.occurrenceFileNames, <String>['a.jpg']);
    });

    test('countOccurrences resets for empty search', () {
      seed(
        const ImageListState(
          occurrencesCount: 5,
          occurrenceFileNames: <String>['x.jpg'],
        ),
      );

      session.countOccurrences('');

      expect(session.current.state.occurrencesCount, 0);
      expect(session.current.state.occurrenceFileNames, isEmpty);
    });

    test('searchAndReplace updates captions and saves db', () async {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(
              id: 'a',
              path: '/f/a.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'old value'),
              },
            ),
            makeImage(
              id: 'b',
              path: '/f/b.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'no match'),
              },
            ),
          ],
          folderPath: '/f',
        ),
      );

      await session.searchAndReplace('old', 'new');

      expect(
        session.current.state.images.first.captions['default']?.text,
        'new value',
      );
      expect(store.writtenDbs, hasLength(1));
    });

    test('searchAndReplace does nothing when search is empty', () async {
      seed(
        ImageListState(
          images: <AppImage>[makeImage(id: 'a', path: '/f/a.jpg')],
          folderPath: '/f',
        ),
      );

      await session.searchAndReplace('', 'new');

      expect(store.writtenDbs, isEmpty);
    });
  });

  group('CaptionSessionService sort', () {
    test('onSortChanged sorts by name ascending', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(id: 'b', path: '/f/b.jpg'),
            makeImage(id: 'a', path: '/f/a.jpg'),
          ],
        ),
      );

      session.onSortChanged(SortBy.name, true);

      expect(session.current.state.sortBy, SortBy.name);
      expect(session.current.state.sortAscending, isTrue);
      expect(
        session.current.state.images.map((AppImage i) => i.id).toList(),
        <String>['a', 'b'],
      );
    });

    test('onSortChanged sorts by size descending when ascending false', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(id: 'small', path: '/f/a.jpg', size: 10),
            makeImage(id: 'big', path: '/f/b.jpg', size: 999),
          ],
        ),
      );

      session.onSortChanged(SortBy.size, false);

      expect(
        session.current.state.images.map((AppImage i) => i.id).toList(),
        <String>['small', 'big'],
      );
    });

    test('onSortChanged sorts by caption word count ascending', () {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(
              id: 'long',
              path: '/f/b.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'one two three four'),
              },
            ),
            makeImage(
              id: 'short',
              path: '/f/a.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'one'),
              },
            ),
          ],
        ),
      );

      session.onSortChanged(SortBy.caption, true);

      expect(
        session.current.state.images.map((AppImage i) => i.id).toList(),
        <String>['long', 'short'],
      );
    });
  });

  group('CaptionSessionService caption editing', () {
    test('updateCaption updates caption for current image', () async {
      seed(
        ImageListState(
          images: <AppImage>[
            makeImage(
              id: 'a',
              path: '/f/a.jpg',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'old caption'),
              },
            ),
          ],
          currentImageId: 'a',
          folderPath: '/f',
        ),
      );

      await session.updateCaption(caption: 'new caption');

      expect(
        session.current.state.images.first.captions['default']?.text,
        'new caption',
      );
      expect(store.writtenDbs, hasLength(1));
    });

    test(
      'updateCaption clears model and timestamp when caption is empty',
      () async {
        seed(
          ImageListState(
            images: <AppImage>[
              makeImage(
                id: 'a',
                path: '/f/a.jpg',
                captions: <String, CaptionEntry>{
                  'default': CaptionEntry(
                    text: 'old',
                    model: 'gpt-4',
                    timestamp: DateTime(2024),
                  ),
                },
              ),
            ],
            currentImageId: 'a',
            folderPath: '/f',
          ),
        );

        await session.updateCaption(caption: '');

        expect(
          session.current.state.images.first.captions['default']?.model,
          isNull,
        );
        expect(store.writtenDbs, hasLength(1));
      },
    );

    test('updateCaption does nothing when no current image', () async {
      seed(const ImageListState(folderPath: '/f'));

      await session.updateCaption(caption: 'text');

      expect(store.writtenDbs, isEmpty);
    });

    test('updateImage replaces image at correct index', () async {
      seed(
        ImageListState(
          images: <AppImage>[makeImage(id: 'a', path: '/f/a.jpg')],
          folderPath: '/f',
        ),
      );

      await session.updateImage(
        image: makeImage(id: 'a', path: '/f/a.jpg', size: 999),
      );

      expect(session.current.state.images.first.size, 999);
      expect(store.writtenDbs, hasLength(1));
    });

    test('updateImage does nothing when image id not found', () async {
      seed(
        ImageListState(
          images: <AppImage>[makeImage(id: 'a', path: '/f/a.jpg')],
          folderPath: '/f',
        ),
      );

      await session.updateImage(
        image: makeImage(id: 'z', path: '/f/z.jpg'),
      );

      expect(store.writtenDbs, isEmpty);
    });

    test('saveChanges persists db when folderPath is set', () async {
      seed(
        ImageListState(
          images: <AppImage>[makeImage(id: 'a', path: '/f/a.jpg')],
          folderPath: '/test/path',
        ),
      );

      await session.saveChanges();

      expect(store.writtenDbs, hasLength(1));
    });

    test('saveChanges does nothing when folderPath is null', () async {
      seed(const ImageListState());

      await session.saveChanges();

      expect(store.writtenDbs, isEmpty);
    });

    test('_saveDb persists tags onto CaptionData entries', () async {
      // Real store round-trip: the db must keep the tags.
      final Directory tempDir = Directory.systemTemp.createTempSync(
        'session_tags_test_',
      );
      File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');
      final CaptionSessionService real = CaptionSessionService(
        fileStore: AppFileUtils(),
        filterEngine: const FilterParserCaptionEngine(),
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      await real.onFolderPicked(tempDir.path);
      final AppImage image = real.current.state.images.first.copyWith(
        tags: const <String>['sunset', 'landscape'],
      );
      await real.updateImage(image: image);

      final File dbFile = File(p.join(tempDir.path, 'db.json'));
      final Map<String, dynamic> json =
          jsonDecode(dbFile.readAsStringSync()) as Map<String, dynamic>;
      final CaptionDatabase db = CaptionDatabase.fromJson(json);

      expect(db.images, hasLength(1));
      expect(db.images.first.tags, <String>['sunset', 'landscape']);
      real.dispose();
    });
  });

  group('CaptionSessionService categories', () {
    test('addCategory adds and activates it', () {
      session.addCategory('tags');
      expect(session.current.state.categories, contains('tags'));
      expect(session.current.state.activeCategory, 'tags');
    });

    test('prevents duplicate category names', () {
      session.addCategory('tags');
      session.addCategory('tags');
      expect(
        session.current.state.categories
            .where((String c) => c == 'tags')
            .length,
        1,
      );
    });

    test('removeCategory switches active if needed', () {
      seed(
        const ImageListState(
          categories: <String>['default', 'tags'],
          activeCategory: 'tags',
          folderPath: '/f',
        ),
      );

      session.removeCategory('tags');

      expect(session.current.state.categories, isNot(contains('tags')));
      expect(session.current.state.activeCategory, 'default');
    });

    test('prevents removing last category', () {
      seed(const ImageListState(folderPath: '/f'));

      session.removeCategory('default');

      expect(session.current.state.categories, contains('default'));
    });

    test('renameCategory renames category and active', () {
      seed(
        const ImageListState(
          categories: <String>['default', 'old'],
          activeCategory: 'old',
          folderPath: '/f',
        ),
      );

      session.renameCategory('old', 'new');

      expect(session.current.state.categories, contains('new'));
      expect(session.current.state.categories, isNot(contains('old')));
      expect(session.current.state.activeCategory, 'new');
    });

    test('prevents renaming to existing category name', () {
      seed(
        const ImageListState(
          categories: <String>['default', 'tags'],
          folderPath: '/f',
        ),
      );

      session.renameCategory('tags', 'default');

      expect(
        session.current.state.categories
            .where((String c) => c == 'default')
            .length,
        1,
      );
    });

    test('setActiveCategory sets active category when valid', () {
      seed(const ImageListState(categories: <String>['default', 'custom']));

      session.setActiveCategory('custom');

      expect(session.current.state.activeCategory, 'custom');
    });

    test('setActiveCategory does nothing for invalid category', () {
      seed(const ImageListState());

      session.setActiveCategory('nonexistent');

      expect(session.current.state.activeCategory, 'default');
    });

    test('reorderCategories moves category correctly', () {
      seed(
        const ImageListState(
          categories: <String>['default', 'custom', 'other'],
          folderPath: '/f',
        ),
      );

      session.reorderCategories(0, 2);

      expect(session.current.state.categories, <String>[
        'custom',
        'default',
        'other',
      ]);
    });
  });

  group('CaptionSessionService tag operations', () {
    late Directory tempDir;
    late CaptionSessionService real;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('session_tags_ops_');
      File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');
      // Seed a db.json so onFolderPicked loads one image.
      File(p.join(tempDir.path, 'db.json')).writeAsStringSync(
        jsonEncode(<String, Object>{
          'version': 3,
          'categories': <String>['default'],
          'activeCategory': 'default',
          'images': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'img-1',
              'filename': 'a.jpg',
              'captions': <String, dynamic>{},
              'tags': <String>[],
            },
          ],
        }),
      );
      real = CaptionSessionService(
        fileStore: AppFileUtils(),
        filterEngine: const FilterParserCaptionEngine(),
      );
      await real.onFolderPicked(tempDir.path);
      real.selectImage('img-1');
    });

    tearDown(() {
      real.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    AppImage currentImage(CaptionSessionService s) =>
        s.current.state.images.firstWhere((AppImage i) => i.id == 'img-1');

    test('addTag appends a new tag and persists', () async {
      await real.addTag('sunset');
      expect(currentImage(real).tags, <String>['sunset']);
      final Map<String, dynamic> json =
          jsonDecode(File(p.join(tempDir.path, 'db.json')).readAsStringSync())
              as Map<String, dynamic>;
      final Map<String, dynamic> firstImage =
          (json['images'] as List<dynamic>).first as Map<String, dynamic>;
      expect(firstImage['tags'], <String>['sunset']);
    });

    test('addTag dedupes and trims', () async {
      await real.addTag('sunset');
      await real.addTag('  sunset  ');
      expect(currentImage(real).tags, <String>['sunset']);
    });

    test('addTag ignores empty/whitespace input', () async {
      await real.addTag('   ');
      expect(currentImage(real).tags, <String>[]);
    });

    test('removeTag removes an existing tag', () async {
      await real.addTag('sunset');
      await real.addTag('landscape');
      await real.removeTag('sunset');
      expect(currentImage(real).tags, <String>['landscape']);
    });

    test('setTags replaces the whole list (normalized + deduped)', () async {
      await real.addTag('old');
      await real.setTags(<String>['  sunset  ', 'night', 'sunset']);
      expect(currentImage(real).tags, <String>['sunset', 'night']);
    });

    test('operations are no-op when no image selected', () async {
      real.adopt(real.current.state.copyWith(images: <AppImage>[]));
      await real.addTag('x');
      expect(real.current.state.images, isEmpty);
    });
  });

  group('CaptionSessionService guidance', () {
    test('setGuidance stores and clears per-path guidance', () {
      session.setGuidanceEnabled(true);
      session.setGuidance('/f/a.jpg', 'focus on cat');
      expect(session.current.state.guidanceEnabled, isTrue);
      expect(session.current.state.imageGuidance['/f/a.jpg'], 'focus on cat');

      session.setGuidance('/f/a.jpg', '');
      expect(session.current.state.imageGuidance, isEmpty);
    });
  });
}
