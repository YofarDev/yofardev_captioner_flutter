import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/captioning/data/models/batch_apply_template.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/captioning/logic/batch_apply/batch_json_apply_cubit.dart';
import 'package:yofardev_captioner/features/captioning/logic/batch_apply/batch_json_apply_state.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'batch_json_apply_cubit_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit])
void main() {
  late MockImageListCubit mockImageListCubit;

  setUp(() {
    mockImageListCubit = MockImageListCubit();
    when(mockImageListCubit.updateImage(image: anyNamed('image')))
        .thenAnswer((_) async {});
  });

  group('BatchJsonApplyCubit', () {
    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'emits completed when no images',
      build: () {
        when(mockImageListCubit.state).thenReturn(const ImageListState());
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) => cubit.apply(const BatchApplyTemplate(aesthetics: 'test')),
      expect: () => <dynamic>[isA<BatchJsonApplyCompleted>()],
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'processes JSON caption images',
      build: () {
        when(mockImageListCubit.state).thenReturn(ImageListState(
          images: <AppImage>[
            AppImage(
              id: '1',
              image: File('/fake/img.jpg'),
              captions: const <String, CaptionEntry>{
                'default': CaptionEntry(
                  text:
                      '{"high_level_description":"old","style_description":{"aesthetics":"old","lighting":"old","medium":"photograph","photo":"","color_palette":[]},"compositional_deconstruction":{"background":"","elements":[]}}',
                ),
              },
              size: 100,
            ),
          ],
        ));
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) => cubit.apply(
        const BatchApplyTemplate(aesthetics: 'new_aes'),
      ),
      expect: () => <dynamic>[
        isA<BatchJsonApplyInProgress>(),
        isA<BatchJsonApplyCompleted>(),
      ],
      verify: (_) {
        verify(mockImageListCubit.updateImage(image: anyNamed('image')))
            .called(1);
      },
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'skips plain text captions',
      build: () {
        when(mockImageListCubit.state).thenReturn(ImageListState(
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
        ));
        return BatchJsonApplyCubit(mockImageListCubit);
      },
      act: (BatchJsonApplyCubit cubit) => cubit.apply(
        const BatchApplyTemplate(aesthetics: 'new_aes'),
      ),
      expect: () => <dynamic>[isA<BatchJsonApplyCompleted>()],
      verify: (_) {
        verifyNever(mockImageListCubit.updateImage(image: anyNamed('image')));
      },
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'creates minimal JSON for empty captions',
      build: () {
        when(mockImageListCubit.state).thenReturn(ImageListState(
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
        ));
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
        verify(mockImageListCubit.updateImage(image: anyNamed('image')))
            .called(1);
      },
    );

    blocTest<BatchJsonApplyCubit, BatchJsonApplyState>(
      'supports cancellation',
      build: () {
        when(mockImageListCubit.state).thenReturn(ImageListState(
          images: List<AppImage>.generate(3, (int i) => AppImage(
            id: '$i',
            image: File('/fake/img$i.jpg'),
            captions: const <String, CaptionEntry>{
              'default': CaptionEntry(
                text:
                    '{"high_level_description":"old","style_description":{"aesthetics":"old","lighting":"old","medium":"photograph","photo":"","color_palette":[]},"compositional_deconstruction":{"background":"","elements":[]}}',
              ),
            },
            size: 100,
          )),
        ));
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
