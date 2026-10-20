import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/caption_repository.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/captioning_repository.dart';

import 'captioning_repository_test.mocks.dart';

@GenerateMocks(<Type>[CaptionRepository])
void main() {
  // Mockito cannot synthesize Either dummies for the new signatures.
  provideDummy<Either<Failure, String>>(const Right<Failure, String>(''));

  group('CaptioningRepository', () {
    late CaptioningRepository repository;
    late MockCaptionRepository mockInner;

    final LlmConfig config = LlmConfig(
      id: '1',
      name: 'cfg',
      model: 'gpt-4',
      providerType: LlmProviderType.remote,
    );

    final AppImage image = AppImage(
      id: 'img',
      image: File('/x/y.jpg'),
      captions: const <String, CaptionEntry>{},
    );

    setUp(() {
      mockInner = MockCaptionRepository();
      repository = CaptioningRepository(captionRepository: mockInner);
    });

    test('captionImage delegates and stores caption under category', () async {
      when(
        mockInner.getCaption(any, any, any),
      ).thenAnswer((_) async => const Right<Failure, String>('a caption'));

      final Either<Failure, AppImage> result = await repository.captionImage(
        config,
        image,
        'prompt',
      );

      verify(mockInner.getCaption(config, image, 'prompt')).called(1);
      final AppImage updated = result.getRight().toNullable()!;
      expect(updated.captions['default']?.text, 'a caption');
      expect(updated.captions['default']?.model, 'cfg');
      expect(updated.captions['default']?.isEdited, isFalse);
      expect(updated.lastModified, isNotNull);
    });

    test(
      'captionImage writes to custom category and preserves siblings',
      () async {
        final AppImage withSibling = image.copyWith(
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'old'),
          },
        );
        when(
          mockInner.getCaption(any, any, any),
        ).thenAnswer((_) async => const Right<Failure, String>('new'));

        final Either<Failure, AppImage> result = await repository.captionImage(
          config,
          withSibling,
          'prompt',
          category: 'alt',
        );

        final AppImage updated = result.getRight().toNullable()!;
        expect(updated.captions['default']?.text, 'old'); // preserved
        expect(updated.captions['alt']?.text, 'new'); // added
      },
    );

    test('rewriteCaption marks result as edited', () async {
      when(
        mockInner.rewriteCaption(any, any, any),
      ).thenAnswer((_) async => const Right<Failure, String>('rewritten'));

      final Either<Failure, AppImage> result = await repository.rewriteCaption(
        config,
        image,
        'make it shorter',
      );

      verify(mockInner.rewriteCaption(config, '', 'make it shorter')).called(1);
      final AppImage updated = result.getRight().toNullable()!;
      expect(updated.captions['default']?.text, 'rewritten');
      expect(updated.captions['default']?.isEdited, isTrue);
    });

    test('rewriteCaption passes through when original is plain text', () async {
      when(
        mockInner.rewriteCaption(any, any, any),
      ).thenAnswer((_) async => const Right<Failure, String>('still plain'));

      final AppImage plain = image.copyWith(
        captions: <String, CaptionEntry>{
          'default': const CaptionEntry(text: 'plain'),
        },
      );

      final Either<Failure, AppImage> result = await repository.rewriteCaption(
        config,
        plain,
        'instructions',
      );

      expect(
        result.getRight().toNullable()!.captions['default']?.text,
        'still plain',
      );
    });

    test('rewriteCaption accepts valid JSON when original was JSON', () async {
      when(
        mockInner.rewriteCaption(any, any, any),
      ).thenAnswer((_) async => const Right<Failure, String>('{"k": "v"}'));

      final AppImage withJson = image.copyWith(
        captions: <String, CaptionEntry>{
          'default': const CaptionEntry(text: '{"k": "old"}'),
        },
      );

      final Either<Failure, AppImage> result = await repository.rewriteCaption(
        config,
        withJson,
        'instructions',
      );

      expect(
        result.getRight().toNullable()!.captions['default']?.text,
        '{"k": "v"}',
      );
    });

    test(
      'rewriteCaption throws when original was JSON but result is not',
      () async {
        when(mockInner.rewriteCaption(any, any, any)).thenAnswer(
          (_) async => const Right<Failure, String>('not json at all'),
        );

        final AppImage withJson = image.copyWith(
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: '{"k": "old"}'),
          },
        );

        final Either<Failure, AppImage> result = await repository
            .rewriteCaption(config, withJson, 'instructions');

        expect(result.getLeft().toNullable(), isA<FailureInvalidData>());
      },
    );
  });
}
