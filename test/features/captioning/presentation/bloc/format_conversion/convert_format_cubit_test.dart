import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/moss_format.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';
import 'package:yofardev_captioner/core/models/structured_caption_document.dart';
import 'package:yofardev_captioner/core/services/image_dimension_resolver.dart';
import 'package:yofardev_captioner/core/services/moss_conversion_service.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/format_conversion/convert_format_cubit.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/format_conversion/convert_format_state.dart';

import 'convert_format_cubit_test.mocks.dart';

@GenerateMocks(<Type>[CaptionSessionService])
void main() {
  late MockCaptionSessionService session;

  const String ideogramJson =
      '{"high_level_description":"a photo","style_description":{"aesthetics":"", '
      '"lighting":"","photo":"","medium":"photograph","color_palette":[]}, '
      '"compositional_deconstruction":{"background":"","elements": '
      '[{"type":"obj","bbox":[0,0,500,1000],"desc":"a thing"}]}}';
  const String mossJson =
      '{"width":1024,"height":1024,"bbox_coord_space":"abs",'
      '"bbox_format":"xyxy","summary":{"caption":"s"},"items":[]}';

  setUp(() {
    session = MockCaptionSessionService();
    when(
      session.addCategory(any, format: anyNamed('format')),
    ).thenAnswer((Invocation invocation) async {});
    when(
      session.updateImageCaption(
        imageId: anyNamed('imageId'),
        category: anyNamed('category'),
        text: anyNamed('text'),
        model: anyNamed('model'),
        sourceCategory: anyNamed('sourceCategory'),
        expectedSourceText: anyNamed('expectedSourceText'),
      ),
    ).thenAnswer((Invocation invocation) async => true);
  });

  MossConversionService fakeLookupService(ImageDimensions dims) =>
      MossConversionService(dimensionLookup: (File _) async => dims);

  group('ConvertFormatCubit', () {
    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'emits completed(converted: 0) when nothing matches the source format',
      build: () {
        when(session.state).thenReturn(const ImageListState());
        return ConvertFormatCubit(session);
      },
      act: (ConvertFormatCubit cubit) =>
          cubit.apply(target: CaptionFormat.moss, inPlace: true),
      expect: () => <dynamic>[isA<ConvertFormatCompleted>()],
      verify: (ConvertFormatCubit _) {
        verifyNever(
          session.updateImageCaption(
            imageId: anyNamed('imageId'),
            category: anyNamed('category'),
            text: anyNamed('text'),
          ),
        );
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'ideogram → moss projects boxes onto the EXACT source dimensions '
      '(1864×1864 stays 1864×1864, no 16px rounding)',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: ideogramJson),
                },
              ),
            ],
          ),
        );
        return ConvertFormatCubit(
          session,
          conversionService: fakeLookupService(
            const ImageDimensions(width: 1864, height: 1864),
          ),
        );
      },
      act: (ConvertFormatCubit cubit) =>
          cubit.apply(target: CaptionFormat.moss, inPlace: true),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit _) {
        final List<dynamic> captured = verify(
          session.updateImageCaption(
            imageId: captureAnyNamed('imageId'),
            category: captureAnyNamed('category'),
            text: captureAnyNamed('text'),
            model: anyNamed('model'),
            sourceCategory: anyNamed('sourceCategory'),
            expectedSourceText: anyNamed('expectedSourceText'),
          ),
        ).captured;
        expect(captured[0], '1');
        expect(captured[1], 'default');
        final String text = captured[2] as String;
        final MossLayoutCaption caption =
            (StructuredCaptionDocument.tryParse(text)! as MossDocument).caption;
        expect(caption.width, 1864);
        expect(caption.height, 1864);
        // ideogram [y1,x1,y2,x2]=[0,0,500,1000] → xyxy [0,0,1864,932]
        expect(caption.items.single.bbox, <int>[0, 0, 1864, 932]);
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'moss → ideogram into a new category creates the category once',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: mossJson),
                },
              ),
            ],
          ),
        );
        return ConvertFormatCubit(session);
      },
      act: (ConvertFormatCubit cubit) => cubit.apply(
        target: CaptionFormat.ideogram,
        inPlace: false,
        newCategoryName: 'ideogram',
      ),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit _) {
        verify(session.addCategory('ideogram', format: 'json')).called(1);
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'refuses source-equal destination unless in-place mode is selected',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: mossJson),
                },
              ),
            ],
          ),
        );
        return ConvertFormatCubit(session);
      },
      act: (ConvertFormatCubit cubit) => cubit.apply(
        target: CaptionFormat.ideogram,
        inPlace: false,
        newCategoryName: 'default',
      ),
      expect: () => <dynamic>[isA<ConvertFormatError>()],
      verify: (ConvertFormatCubit _) {
        verifyNever(session.addCategory(any, format: anyNamed('format')));
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'skips existing destination captions without an explicit overwrite',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: mossJson),
                  'ideogram': CaptionEntry(text: 'existing'),
                },
              ),
            ],
          ),
        );
        return ConvertFormatCubit(session);
      },
      act: (ConvertFormatCubit cubit) => cubit.apply(
        target: CaptionFormat.ideogram,
        inPlace: false,
        newCategoryName: 'ideogram',
      ),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit _) {
        verifyNever(
          session.updateImageCaption(
            imageId: anyNamed('imageId'),
            category: anyNamed('category'),
            text: anyNamed('text'),
          ),
        );
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'destination caption created DURING conversion is not overwritten '
      '(final-write re-check)',
      build: () {
        // Deterministic race: the destination caption "appears" as soon as
        // the (fake) conversion completes — i.e. exactly between the
        // pre-conversion collision check and the final-write re-check.
        bool conversionDone = false;
        when(session.state).thenAnswer((Invocation _) {
          if (!conversionDone) {
            return ImageListState(
              images: <AppImage>[
                AppImage(
                  id: '1',
                  image: File('/fake/img.jpg'),
                  captions: const <String, CaptionEntry>{
                    'default': CaptionEntry(text: ideogramJson),
                  },
                ),
              ],
            );
          }
          return ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: ideogramJson),
                  'moss': CaptionEntry(text: 'created mid-run'),
                },
              ),
            ],
          );
        });
        return ConvertFormatCubit(
          session,
          conversionService: MossConversionService(
            dimensionLookup: (File _) async {
              conversionDone = true;
              return const ImageDimensions(width: 1024, height: 1024);
            },
          ),
        );
      },
      act: (ConvertFormatCubit cubit) => cubit.apply(
        target: CaptionFormat.moss,
        inPlace: false,
        newCategoryName: 'moss',
      ),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit cubit) {
        final ConvertFormatCompleted done =
            cubit.state as ConvertFormatCompleted;
        expect(done.converted, 0);
        expect(done.skipped, 1);
        expect(
          done.diagnostics.any(
            (MossFormatDiagnostic d) =>
                d.code == MossDiagnosticCodes.destinationCollision,
          ),
          isTrue,
        );
        verifyNever(
          session.updateImageCaption(
            imageId: anyNamed('imageId'),
            category: anyNamed('category'),
            text: anyNamed('text'),
          ),
        );
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'a conversion crash reports failed and still completes the run',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: ideogramJson),
                },
              ),
            ],
          ),
        );
        return ConvertFormatCubit(
          session,
          conversionService: MossConversionService(
            dimensionLookup: (File _) => throw StateError('disk exploded'),
          ),
        );
      },
      act: (ConvertFormatCubit cubit) =>
          cubit.apply(target: CaptionFormat.moss, inPlace: true),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit cubit) {
        final ConvertFormatCompleted done =
            cubit.state as ConvertFormatCompleted;
        expect(done.failed, 1);
        expect(done.diagnostics, isNotEmpty);
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'a persistence failure during the write is reported as a diagnostic',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: ideogramJson),
                },
              ),
            ],
          ),
        );
        when(
          session.updateImageCaption(
            imageId: anyNamed('imageId'),
            category: anyNamed('category'),
            text: anyNamed('text'),
            model: anyNamed('model'),
            sourceCategory: anyNamed('sourceCategory'),
            expectedSourceText: anyNamed('expectedSourceText'),
          ),
        ).thenThrow(StateError('db write failed'));
        return ConvertFormatCubit(
          session,
          conversionService: fakeLookupService(
            const ImageDimensions(width: 1864, height: 1864),
          ),
        );
      },
      act: (ConvertFormatCubit cubit) =>
          cubit.apply(target: CaptionFormat.moss, inPlace: true),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit cubit) {
        final ConvertFormatCompleted done =
            cubit.state as ConvertFormatCompleted;
        // The run must complete with a failure report, not die mid-way.
        expect(done.failed, 1);
        expect(
          done.diagnostics.map((MossFormatDiagnostic d) => d.message).join(' '),
          contains('db write failed'),
        );
      },
    );

    blocTest<ConvertFormatCubit, ConvertFormatState>(
      'unreadable image dimensions fail visibly (no invented 1024 frame)',
      build: () {
        when(session.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: ideogramJson),
                },
              ),
            ],
          ),
        );
        return ConvertFormatCubit(
          session,
          conversionService: MossConversionService(
            dimensionLookup: (File _) async => null,
          ),
        );
      },
      act: (ConvertFormatCubit cubit) =>
          cubit.apply(target: CaptionFormat.moss, inPlace: true),
      expect: () => <dynamic>[
        isA<ConvertFormatInProgress>(),
        isA<ConvertFormatCompleted>(),
      ],
      verify: (ConvertFormatCubit _) {
        verifyNever(
          session.updateImageCaption(
            imageId: anyNamed('imageId'),
            category: anyNamed('category'),
            text: anyNamed('text'),
          ),
        );
      },
    );
  });
}
