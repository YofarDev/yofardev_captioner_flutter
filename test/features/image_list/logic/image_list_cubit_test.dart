import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_data.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_database.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

import 'image_list_cubit_test.mocks.dart';

@GenerateMocks(<Type>[AppFileUtils])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for tests
  SharedPreferences.setMockInitialValues(<String, Object>{});

  const MethodChannel channel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

  // Helper to create test images with predictable properties
  AppImage makeImage({
    required String id,
    required String path,
    int size = 100,
    int width = -1,
    int height = -1,
    Map<String, CaptionEntry>? captions,
  }) {
    return AppImage(
      id: id,
      image: File(path),
      captions: captions ?? const <String, CaptionEntry>{},
      size: size,
      width: width,
      height: height,
    );
  }

  group('ImageListCubit', () {
    late ImageListCubit imageListCubit;
    late MockAppFileUtils mockAppFileUtils;

    setUp(() {
      mockAppFileUtils = MockAppFileUtils();
      imageListCubit = ImageListCubit(fileUtils: mockAppFileUtils);
    });

    // ─── Existing tests ────────────────────────────────────────────

    final AppImage testImage = AppImage(
      id: const Uuid().v4(),
      image: File('test/test_resources/test_image.jpg'),
      captions: const <String, CaptionEntry>{},
      size: 123,
    );

    blocTest<ImageListCubit, ImageListState>(
      'emits new state and calls file utils when removeImage is called',
      build: () {
        when(
          mockAppFileUtils.removeImage(any),
        ).thenAnswer((_) => Future<void>.value());
        return imageListCubit;
      },
      seed: () => ImageListState(images: <AppImage>[testImage]),
      act: (ImageListCubit cubit) => cubit.removeImage(testImage.id),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>().having(
          (ImageListState state) => state.images,
          'images',
          isEmpty,
        ),
      ],
      verify: (_) {
        verify(mockAppFileUtils.removeImage(testImage.image)).called(1);
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'onFolderPicked loads images when folder changes',
      build: () {
        when(
          mockAppFileUtils.onFolderPicked(any),
        ).thenAnswer((_) async => <AppImage>[testImage]);
        when(mockAppFileUtils.readDb(any)).thenAnswer(
          (_) async => CaptionDatabase(
            categories: <String>['default'],
            images: <CaptionData>[],
          ),
        );
        return imageListCubit;
      },
      act: (ImageListCubit cubit) => cubit.onFolderPicked('/new/path'),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>()
            .having(
              (ImageListState s) => s.folderPath,
              'folderPath',
              '/new/path',
            )
            .having(
              (ImageListState s) => s.images,
              'images',
              isEmpty,
            ), // Initial empty state
        isA<ImageListState>()
            .having(
              (ImageListState s) => s.folderPath,
              'folderPath',
              '/new/path',
            )
            .having(
              (ImageListState s) => s.images,
              'images',
              hasLength(1),
            ), // Loaded images
      ],
      verify: (_) {
        verify(mockAppFileUtils.onFolderPicked('/new/path')).called(1);
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'onFolderPicked does NOTHING when folder is same and force is false',
      build: () {
        return imageListCubit;
      },
      seed: () => const ImageListState(folderPath: '/existing/path'),
      act: (ImageListCubit cubit) => cubit.onFolderPicked('/existing/path'),
      expect: () => <ImageListState>[], // No state emitted
      verify: (_) {
        verifyNever(mockAppFileUtils.onFolderPicked(any));
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'onFolderPicked reloads images when folder is same AND force is TRUE',
      build: () {
        when(
          mockAppFileUtils.onFolderPicked(any),
        ).thenAnswer((_) async => <AppImage>[testImage]);
        when(mockAppFileUtils.readDb(any)).thenAnswer(
          (_) async => CaptionDatabase(
            categories: <String>['default'],
            images: <CaptionData>[],
          ),
        );
        return imageListCubit;
      },
      seed: () => ImageListState(
        folderPath: '/existing/path',
        images: <AppImage>[testImage],
      ),
      act: (ImageListCubit cubit) =>
          cubit.onFolderPicked('/existing/path', force: true),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>().having(
          (ImageListState s) => s.images,
          'images',
          isEmpty,
        ), // Reset images
        isA<ImageListState>().having(
          (ImageListState s) => s.images,
          'images',
          hasLength(1),
        ), // Reloaded
      ],
      verify: (_) {
        verify(mockAppFileUtils.onFolderPicked('/existing/path')).called(1);
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'duplicateImage adds duplicated image to list and updates index',
      build: () {
        final AppImage duplicatedImage = AppImage(
          id: 'duplicated-id',
          image: File('test/test_resources/test_image_copy.jpg'),
          captions: const <String, CaptionEntry>{},
          size: 123,
        );
        when(
          mockAppFileUtils.duplicateImage(any),
        ).thenAnswer((_) async => duplicatedImage);
        when(mockAppFileUtils.compareNatural(any, any)).thenReturn(0);
        when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
        return imageListCubit;
      },
      seed: () => ImageListState(
        folderPath: '/test/path',
        images: <AppImage>[testImage],
      ),
      act: (ImageListCubit cubit) => cubit.duplicateImage(),
      expect: () => <TypeMatcher<ImageListState>>[
        isA<ImageListState>()
            .having((ImageListState s) => s.images, 'images', hasLength(2))
            .having(
              (ImageListState s) => s.currentImageId,
              'currentImageId',
              isNotNull,
            ),
      ],
      verify: (_) {
        verify(mockAppFileUtils.duplicateImage(testImage)).called(1);
        verify(mockAppFileUtils.writeDb(any, any)).called(1);
      },
    );

    blocTest<ImageListCubit, ImageListState>(
      'duplicateImage does nothing when images list is empty',
      build: () {
        return imageListCubit;
      },
      seed: () => const ImageListState(),
      act: (ImageListCubit cubit) => cubit.duplicateImage(),
      expect: () => <ImageListState>[],
      verify: (_) {
        verifyNever(mockAppFileUtils.duplicateImage(any));
      },
    );

    // ─── Navigation tests ──────────────────────────────────────────

    group('navigation', () {
      late AppImage imgA;
      late AppImage imgB;
      late AppImage imgC;
      late List<AppImage> threeImages;

      setUp(() {
        imgA = makeImage(id: 'a', path: '/folder/a.jpg');
        imgB = makeImage(id: 'b', path: '/folder/b.jpg');
        imgC = makeImage(id: 'c', path: '/folder/c.jpg');
        threeImages = <AppImage>[imgA, imgB, imgC];
      });

      blocTest<ImageListCubit, ImageListState>(
        'nextImage advances to next image',
        build: () => imageListCubit,
        seed: () => ImageListState(images: threeImages, currentImageId: 'a'),
        act: (ImageListCubit cubit) => cubit.nextImage(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.currentImageId,
            'currentImageId',
            'b',
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'nextImage wraps from last to first',
        build: () => imageListCubit,
        seed: () => ImageListState(images: threeImages, currentImageId: 'c'),
        act: (ImageListCubit cubit) => cubit.nextImage(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.currentImageId,
            'currentImageId',
            'a',
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'nextImage does nothing when images empty',
        build: () => imageListCubit,
        seed: () => const ImageListState(),
        act: (ImageListCubit cubit) => cubit.nextImage(),
        expect: () => <ImageListState>[],
      );

      blocTest<ImageListCubit, ImageListState>(
        'previousImage goes to previous image',
        build: () => imageListCubit,
        seed: () => ImageListState(images: threeImages, currentImageId: 'c'),
        act: (ImageListCubit cubit) => cubit.previousImage(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.currentImageId,
            'currentImageId',
            'b',
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'previousImage wraps from first to last',
        build: () => imageListCubit,
        seed: () => ImageListState(images: threeImages, currentImageId: 'a'),
        act: (ImageListCubit cubit) => cubit.previousImage(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.currentImageId,
            'currentImageId',
            'c',
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'previousImage does nothing when images empty',
        build: () => imageListCubit,
        seed: () => const ImageListState(),
        act: (ImageListCubit cubit) => cubit.previousImage(),
        expect: () => <ImageListState>[],
      );
    });

    // ─── Search tests ──────────────────────────────────────────────

    group('search', () {
      blocTest<ImageListCubit, ImageListState>(
        'updateSearchQuery sets query and resets to first image',
        build: () => imageListCubit,
        seed: () {
          final AppImage imgA = makeImage(id: 'a', path: '/f/a.jpg');
          final AppImage imgB = makeImage(id: 'b', path: '/f/b.jpg');
          return ImageListState(
            images: <AppImage>[imgA, imgB],
            currentImageId: 'b',
          );
        },
        act: (ImageListCubit cubit) => cubit.updateSearchQuery('cat'),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>()
              .having((ImageListState s) => s.searchQuery, 'searchQuery', 'cat')
              .having(
                (ImageListState s) => s.currentImageId,
                'currentImageId',
                'a',
              ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'updateSearchQuery with empty string sets currentImageId to first',
        build: () => imageListCubit,
        seed: () {
          final AppImage imgA = makeImage(id: 'a', path: '/f/a.jpg');
          return ImageListState(
            images: <AppImage>[imgA],
            searchQuery: 'old',
            currentImageId: 'a',
          );
        },
        act: (ImageListCubit cubit) => cubit.updateSearchQuery(''),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>()
              .having((ImageListState s) => s.searchQuery, 'searchQuery', '')
              .having(
                (ImageListState s) => s.currentImageId,
                'currentImageId',
                'a',
              ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'toggleCaseSensitive flips from false to true',
        build: () => imageListCubit,
        seed: () => const ImageListState(),
        act: (ImageListCubit cubit) => cubit.toggleCaseSensitive(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.caseSensitive,
            'caseSensitive',
            true,
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'toggleCaseSensitive flips from true to false',
        build: () => imageListCubit,
        seed: () => const ImageListState(caseSensitive: true),
        act: (ImageListCubit cubit) => cubit.toggleCaseSensitive(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.caseSensitive,
            'caseSensitive',
            false,
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'clearSearch resets query and caseSensitive',
        build: () => imageListCubit,
        seed: () =>
            const ImageListState(searchQuery: 'cat', caseSensitive: true),
        act: (ImageListCubit cubit) => cubit.clearSearch(),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>()
              .having((ImageListState s) => s.searchQuery, 'searchQuery', '')
              .having(
                (ImageListState s) => s.caseSensitive,
                'caseSensitive',
                false,
              ),
        ],
      );

      test('filteredImages returns all images when no search query', () {
        final AppImage imgA = makeImage(id: 'a', path: '/f/a.jpg');
        final AppImage imgB = makeImage(id: 'b', path: '/f/b.jpg');
        imageListCubit.emit(ImageListState(images: <AppImage>[imgA, imgB]));

        expect(imageListCubit.filteredImages, hasLength(2));
      });

      test('filteredImages filters by caption text case-insensitive', () {
        final AppImage imgA = makeImage(
          id: 'a',
          path: '/f/a.jpg',
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'a Cat sitting'),
          },
        );
        final AppImage imgB = makeImage(
          id: 'b',
          path: '/f/b.jpg',
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'a Dog running'),
          },
        );
        imageListCubit.emit(
          ImageListState(images: <AppImage>[imgA, imgB], searchQuery: 'cat'),
        );

        final List<AppImage> filtered = imageListCubit.filteredImages;
        expect(filtered, hasLength(1));
        expect(filtered.first.id, 'a');
      });

      test('filteredImages respects caseSensitive flag', () {
        final AppImage imgA = makeImage(
          id: 'a',
          path: '/f/a.jpg',
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'Cat sitting'),
          },
        );
        final AppImage imgB = makeImage(
          id: 'b',
          path: '/f/b.jpg',
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'cat sitting'),
          },
        );
        imageListCubit.emit(
          ImageListState(
            images: <AppImage>[imgA, imgB],
            searchQuery: 'Cat',
            caseSensitive: true,
          ),
        );

        final List<AppImage> filtered = imageListCubit.filteredImages;
        expect(filtered, hasLength(1));
        expect(filtered.first.id, 'a');
      });

      blocTest<ImageListCubit, ImageListState>(
        'countOccurrences counts matches and collects filenames',
        build: () => imageListCubit,
        seed: () {
          final AppImage imgA = makeImage(
            id: 'a',
            path: '/folder/a.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'cat dog cat'),
            },
          );
          final AppImage imgB = makeImage(
            id: 'b',
            path: '/folder/b.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'bird fish'),
            },
          );
          return ImageListState(images: <AppImage>[imgA, imgB]);
        },
        act: (ImageListCubit cubit) => cubit.countOccurrences('cat'),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>()
              .having(
                (ImageListState s) => s.occurrencesCount,
                'occurrencesCount',
                2,
              )
              .having(
                (ImageListState s) => s.occurrenceFileNames,
                'occurrenceFileNames',
                <String>['a.jpg'],
              ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'countOccurrences resets for empty search',
        build: () => imageListCubit,
        seed: () => const ImageListState(
          occurrencesCount: 5,
          occurrenceFileNames: <String>['x.jpg'],
        ),
        act: (ImageListCubit cubit) => cubit.countOccurrences(''),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>()
              .having(
                (ImageListState s) => s.occurrencesCount,
                'occurrencesCount',
                0,
              )
              .having(
                (ImageListState s) => s.occurrenceFileNames,
                'occurrenceFileNames',
                isEmpty,
              ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'searchAndReplace updates captions and saves db',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () {
          final AppImage imgA = makeImage(
            id: 'a',
            path: '/f/a.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'old value'),
            },
          );
          final AppImage imgB = makeImage(
            id: 'b',
            path: '/f/b.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'no match'),
            },
          );
          return ImageListState(
            images: <AppImage>[imgA, imgB],
            folderPath: '/f',
          );
        },
        act: (ImageListCubit cubit) => cubit.searchAndReplace('old', 'new'),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.images,
            'images',
            isA<List<AppImage>>().having(
              (List<AppImage> imgs) => imgs.first.captions['default']?.text,
              'first caption',
              'new value',
            ),
          ),
        ],
        verify: (_) {
          verify(mockAppFileUtils.writeDb(any, any)).called(1);
        },
      );

      blocTest<ImageListCubit, ImageListState>(
        'searchAndReplace does nothing when search is empty',
        build: () => imageListCubit,
        seed: () =>
            ImageListState(images: <AppImage>[testImage], folderPath: '/f'),
        act: (ImageListCubit cubit) => cubit.searchAndReplace('', 'new'),
        expect: () => <ImageListState>[],
        verify: (_) {
          verifyNever(mockAppFileUtils.writeDb(any, any));
        },
      );
    });

    // ─── Sort tests ────────────────────────────────────────────────

    group('sort', () {
      blocTest<ImageListCubit, ImageListState>(
        'onSortChanged sorts by name ascending',
        build: () => imageListCubit,
        seed: () {
          final AppImage imgB = makeImage(id: 'b', path: '/f/b.jpg');
          final AppImage imgA = makeImage(id: 'a', path: '/f/a.jpg');
          return ImageListState(images: <AppImage>[imgB, imgA]);
        },
        act: (ImageListCubit cubit) => cubit.onSortChanged(SortBy.name, true),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>()
              .having((ImageListState s) => s.sortBy, 'sortBy', SortBy.name)
              .having(
                (ImageListState s) => s.sortAscending,
                'sortAscending',
                true,
              )
              .having(
                (ImageListState s) =>
                    s.images.map((AppImage i) => i.id).toList(),
                'image order',
                <String>['a', 'b'],
              ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'onSortChanged sorts by size descending when ascending false',
        build: () => imageListCubit,
        seed: () {
          final AppImage imgSmall = makeImage(
            id: 'small',
            path: '/f/a.jpg',
            size: 10,
          );
          final AppImage imgBig = makeImage(
            id: 'big',
            path: '/f/b.jpg',
            size: 999,
          );
          return ImageListState(images: <AppImage>[imgSmall, imgBig]);
        },
        act: (ImageListCubit cubit) => cubit.onSortChanged(SortBy.size, false),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.images.map((AppImage i) => i.id).toList(),
            'image order',
            <String>['small', 'big'],
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'onSortChanged sorts by caption word count ascending',
        build: () => imageListCubit,
        seed: () {
          final AppImage imgLong = makeImage(
            id: 'long',
            path: '/f/b.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'one two three four'),
            },
          );
          final AppImage imgShort = makeImage(
            id: 'short',
            path: '/f/a.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'one'),
            },
          );
          return ImageListState(images: <AppImage>[imgLong, imgShort]);
        },
        act: (ImageListCubit cubit) =>
            cubit.onSortChanged(SortBy.caption, true),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.images.map((AppImage i) => i.id).toList(),
            'image order',
            <String>['long', 'short'],
          ),
        ],
      );
    });

    // ─── Caption editing tests ─────────────────────────────────────

    group('caption editing', () {
      blocTest<ImageListCubit, ImageListState>(
        'updateCaption updates caption for current image',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () {
          final AppImage img = makeImage(
            id: 'a',
            path: '/f/a.jpg',
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'old caption'),
            },
          );
          return ImageListState(
            images: <AppImage>[img],
            currentImageId: 'a',
            folderPath: '/f',
          );
        },
        act: (ImageListCubit cubit) =>
            cubit.updateCaption(caption: 'new caption'),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.images.first.captions['default']?.text,
            'caption text',
            'new caption',
          ),
        ],
        verify: (_) {
          verify(mockAppFileUtils.writeDb(any, any)).called(1);
        },
      );

      blocTest<ImageListCubit, ImageListState>(
        'updateCaption clears model and timestamp when caption is empty',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () {
          final AppImage img = makeImage(
            id: 'a',
            path: '/f/a.jpg',
            captions: <String, CaptionEntry>{
              'default': CaptionEntry(
                text: 'old',
                model: 'gpt-4',
                timestamp: DateTime(2024),
              ),
            },
          );
          return ImageListState(
            images: <AppImage>[img],
            currentImageId: 'a',
            folderPath: '/f',
          );
        },
        act: (ImageListCubit cubit) => cubit.updateCaption(caption: ''),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.images.first.captions['default']?.model,
            'model cleared',
            isNull,
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'updateCaption does nothing when no current image',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () => const ImageListState(folderPath: '/f'),
        act: (ImageListCubit cubit) => cubit.updateCaption(caption: 'text'),
        expect: () => <ImageListState>[],
        verify: (_) {
          verifyNever(mockAppFileUtils.writeDb(any, any));
        },
      );

      blocTest<ImageListCubit, ImageListState>(
        'updateImage replaces image at correct index',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () {
          final AppImage img = makeImage(id: 'a', path: '/f/a.jpg');
          return ImageListState(images: <AppImage>[img], folderPath: '/f');
        },
        act: (ImageListCubit cubit) {
          final AppImage updated = makeImage(
            id: 'a',
            path: '/f/a.jpg',
            size: 999,
          );
          return cubit.updateImage(image: updated);
        },
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.images.first.size,
            'size',
            999,
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'updateImage does nothing when image id not found',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () {
          final AppImage img = makeImage(id: 'a', path: '/f/a.jpg');
          return ImageListState(images: <AppImage>[img], folderPath: '/f');
        },
        act: (ImageListCubit cubit) {
          final AppImage notFound = makeImage(id: 'z', path: '/f/z.jpg');
          return cubit.updateImage(image: notFound);
        },
        expect: () => <ImageListState>[],
      );

      test('saveChanges calls writeDb when folderPath is set', () async {
        when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
        imageListCubit.emit(
          ImageListState(
            images: <AppImage>[testImage],
            folderPath: '/test/path',
          ),
        );

        await imageListCubit.saveChanges();

        verify(mockAppFileUtils.writeDb(any, any)).called(1);
      });

      test('saveChanges does nothing when folderPath is null', () async {
        imageListCubit.emit(const ImageListState());

        await imageListCubit.saveChanges();

        verifyNever(mockAppFileUtils.writeDb(any, any));
      });
    });

    // ─── Utility getter tests ──────────────────────────────────────

    group('utility getters', () {
      test('getAspectRatioCounts returns correct map', () {
        final AppImage img1 = makeImage(
          id: '1',
          path: '/f/a.jpg',
          width: 1024,
          height: 1024,
        );
        final AppImage img2 = makeImage(
          id: '2',
          path: '/f/b.jpg',
          width: 1024,
          height: 768,
        );
        final AppImage img3 = makeImage(
          id: '3',
          path: '/f/c.jpg',
          width: 2048,
          height: 2048,
        );
        imageListCubit.emit(
          ImageListState(images: <AppImage>[img1, img2, img3]),
        );

        final Map<String, int> counts = imageListCubit.getAspectRatioCounts();
        expect(counts['1:1'], 2);
        expect(counts['4:3'], 1);
      });

      test('getTotalImagesSize sums all sizes', () {
        final AppImage img1 = makeImage(id: '1', path: '/f/a.jpg');
        final AppImage img2 = makeImage(id: '2', path: '/f/b.jpg', size: 200);
        final AppImage img3 = makeImage(id: '3', path: '/f/c.jpg', size: 300);
        imageListCubit.emit(
          ImageListState(images: <AppImage>[img1, img2, img3]),
        );

        expect(imageListCubit.getTotalImagesSize(), 600);
      });

      test('getAverageWordsPerCaption computes correct average', () {
        final AppImage img1 = makeImage(
          id: '1',
          path: '/f/a.jpg',
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'one two three'),
          },
        );
        final AppImage img2 = makeImage(
          id: '2',
          path: '/f/b.jpg',
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'four five'),
          },
        );
        imageListCubit.emit(ImageListState(images: <AppImage>[img1, img2]));

        // (3 + 2) / 2 = 2.5
        expect(imageListCubit.getAverageWordsPerCaption(), 2.5);
      });

      test('getAverageWordsPerCaption returns 0 when no captions', () {
        final AppImage img = makeImage(
          id: '1',
          path: '/f/a.jpg',
          captions: const <String, CaptionEntry>{},
        );
        imageListCubit.emit(ImageListState(images: <AppImage>[img]));

        expect(imageListCubit.getAverageWordsPerCaption(), 0.0);
      });
    });

    // ─── Category subset tests ─────────────────────────────────────

    group('category management', () {
      blocTest<ImageListCubit, ImageListState>(
        'setActiveCategory sets active category when valid',
        build: () => imageListCubit,
        seed: () =>
            const ImageListState(categories: <String>['default', 'custom']),
        act: (ImageListCubit cubit) => cubit.setActiveCategory('custom'),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.activeCategory,
            'activeCategory',
            'custom',
          ),
        ],
      );

      blocTest<ImageListCubit, ImageListState>(
        'setActiveCategory does nothing for invalid category',
        build: () => imageListCubit,
        seed: () => const ImageListState(),
        act: (ImageListCubit cubit) => cubit.setActiveCategory('nonexistent'),
        expect: () => <ImageListState>[],
      );

      blocTest<ImageListCubit, ImageListState>(
        'reorderCategories moves category correctly',
        build: () {
          when(mockAppFileUtils.writeDb(any, any)).thenAnswer((_) async {});
          return imageListCubit;
        },
        seed: () => const ImageListState(
          categories: <String>['default', 'custom', 'other'],
          folderPath: '/f',
        ),
        act: (ImageListCubit cubit) => cubit.reorderCategories(0, 2),
        expect: () => <TypeMatcher<ImageListState>>[
          isA<ImageListState>().having(
            (ImageListState s) => s.categories,
            'categories',
            <String>['custom', 'default', 'other'],
          ),
        ],
      );
    });

    // ─── currentDisplayedImage getter tests ────────────────────────

    group('currentDisplayedImage', () {
      test('returns null when no images', () {
        imageListCubit.emit(const ImageListState());
        expect(imageListCubit.currentDisplayedImage, isNull);
      });

      test('returns first image as fallback when currentImageId is null', () {
        final AppImage img = makeImage(id: 'a', path: '/f/a.jpg');
        imageListCubit.emit(ImageListState(images: <AppImage>[img]));
        expect(imageListCubit.currentDisplayedImage?.id, 'a');
      });

      test('returns image matching currentImageId', () {
        final AppImage imgA = makeImage(id: 'a', path: '/f/a.jpg');
        final AppImage imgB = makeImage(id: 'b', path: '/f/b.jpg');
        imageListCubit.emit(
          ImageListState(images: <AppImage>[imgA, imgB], currentImageId: 'b'),
        );
        expect(imageListCubit.currentDisplayedImage?.id, 'b');
      });
    });
  });
}
