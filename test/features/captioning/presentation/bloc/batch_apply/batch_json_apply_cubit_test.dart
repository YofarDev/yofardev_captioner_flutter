import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/captioning/domain/models/batch_apply_template.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/batch_apply/batch_json_apply_cubit.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/batch_apply/batch_json_apply_state.dart';

import 'batch_json_apply_cubit_test.mocks.dart';

@GenerateMocks(<Type>[CaptionSessionService])
void main() {
  late MockCaptionSessionService mockImageListCubit;

  setUp(() {
    mockImageListCubit = MockCaptionSessionService();
    when(
      mockImageListCubit.updateImage(image: anyNamed('image')),
    ).thenAnswer((_) async {});
  });

  group('BatchJsonApplyCubit', () {
    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'emits completed when no images',
      build: () {
        when(mockImageListCubit.state).thenReturn(const ImageListState());
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) =>
          cubit.apply(const BatchApplyTemplate(aesthetics: 'test')),
      expect: () => <dynamic>[isA<BatchJsonApplyCompleted>()],
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'processes JSON caption images',
      build: () {
        when(mockImageListCubit.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(
                    text:
                        '{"high_level_description":"old","style_description":{"aesthetics":"old","lighting":"old","photo":"","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"","elements":[]}}',
                  ),
                },
                size: 100,
              ),
            ],
          ),
        );
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) =>
          cubit.apply(const BatchApplyTemplate(aesthetics: 'new_aes')),
      expect: () => <dynamic>[
        isA<BatchJsonApplyInProgress>(),
        isA<BatchJsonApplyCompleted>(),
      ],
      verify: (_) {
        verify(
          mockImageListCubit.updateImage(image: anyNamed('image')),
        ).called(1);
      },
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'skips plain text captions',
      build: () {
        when(mockImageListCubit.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: 'plain text'),
                },
                size: 100,
              ),
            ],
          ),
        );
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) =>
          cubit.apply(const BatchApplyTemplate(aesthetics: 'new_aes')),
      expect: () => <dynamic>[isA<BatchJsonApplyCompleted>()],
      verify: (_) {
        verifyNever(mockImageListCubit.updateImage(image: anyNamed('image')));
      },
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'creates minimal JSON for empty captions',
      build: () {
        when(mockImageListCubit.state).thenReturn(
          ImageListState(
            images: <AppImage>[
              AppImage(
                id: '1',
                image: File('/fake/img.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(text: ''),
                },
                size: 100,
              ),
            ],
          ),
        );
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) => cubit.apply(
        const BatchApplyTemplate(aesthetics: 'new_aes', lighting: 'soft'),
      ),
      expect: () => <dynamic>[
        isA<BatchJsonApplyInProgress>(),
        isA<BatchJsonApplyCompleted>(),
      ],
      verify: (_) {
        verify(
          mockImageListCubit.updateImage(image: anyNamed('image')),
        ).called(1);
      },
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'supports cancellation',
      build: () {
        when(mockImageListCubit.state).thenReturn(
          ImageListState(
            images: List<AppImage>.generate(
              3,
              (int i) => AppImage(
                id: '$i',
                image: File('/fake/img$i.jpg'),
                captions: const <String, CaptionEntry>{
                  'default': CaptionEntry(
                    text:
                        '{"high_level_description":"old","style_description":{"aesthetics":"old","lighting":"old","photo":"","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"","elements":[]}}',
                  ),
                },
                size: 100,
              ),
            ),
          ),
        );
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) {
        cubit.apply(const BatchApplyTemplate(aesthetics: 'a'));
        cubit.cancel();
      },
      expect: () => <dynamic>[
        isA<BatchJsonApplyInProgress>(),
        isA<BatchJsonApplyError>(),
      ],
    );
  });
}
