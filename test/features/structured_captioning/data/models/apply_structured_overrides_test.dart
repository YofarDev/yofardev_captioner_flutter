import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/structured_batch_overrides.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/apply_structured_overrides.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';

IdeogramCaption _photoCaption() => const IdeogramCaption(
  highLevelDescription: 'a cat',
  styleDescription: IdeogramStyleDescription(
    aesthetics: 'cinematic',
    lighting: 'golden hour',
    medium: 'photograph',
    photo: '50mm f/1.8',
    colorPalette: <String>['#FFFFFF'],
  ),
  compositionalDeconstruction: IdeogramCompositionalDeconstruction(
    background: 'a garden',
    elements: <IdeogramElement>[],
  ),
);

void main() {
  group('applyStructuredOverrides', () {
    test('disabled overrides return caption unchanged', () {
      final IdeogramCaption caption = _photoCaption();
      final IdeogramCaption result = applyStructuredOverrides(
        caption,
        const StructuredBatchOverrides(
          // enabled defaults to false
          overrideMedium: true,
          medium: 'oil painting',
        ),
      );
      expect(identical(result, caption), isTrue);
    });

    test('overridden fields replace original values', () {
      final IdeogramCaption result = applyStructuredOverrides(
        _photoCaption(),
        const StructuredBatchOverrides(
          enabled: true,
          overrideMedium: true,
          medium: 'oil painting',
          overrideAesthetics: true,
          aesthetics: 'moody',
          overrideLighting: true,
          lighting: 'rim light',
          overrideBackground: true,
          background: 'a studio',
        ),
      );
      expect(result.styleDescription.medium, 'oil painting');
      expect(result.styleDescription.aesthetics, 'moody');
      expect(result.styleDescription.lighting, 'rim light');
      expect(result.compositionalDeconstruction.background, 'a studio');
    });

    test(
      'photo detail routes into art_style when medium flips to non-photo',
      () {
        final IdeogramCaption result = applyStructuredOverrides(
          _photoCaption(),
          const StructuredBatchOverrides(
            enabled: true,
            overrideMedium: true,
            medium: 'oil painting',
          ),
        );
        expect(result.styleDescription.medium, 'oil painting');
        expect(result.styleDescription.photo, isNull);
        expect(result.styleDescription.artStyle, '50mm f/1.8');
      },
    );

    test('styleMode override replaces detail slot', () {
      final IdeogramCaption result = applyStructuredOverrides(
        _photoCaption(),
        const StructuredBatchOverrides(
          enabled: true,
          styleMode: 'art_style',
          styleDetail: 'impasto',
        ),
      );
      expect(result.styleDescription.photo, isNull);
      expect(result.styleDescription.artStyle, 'impasto');
    });

    test('non-overridden fields are preserved', () {
      final IdeogramCaption result = applyStructuredOverrides(
        _photoCaption(),
        const StructuredBatchOverrides(
          enabled: true,
          overrideLighting: true,
          lighting: 'blue hour',
        ),
      );
      expect(result.styleDescription.medium, 'photograph');
      expect(result.styleDescription.aesthetics, 'cinematic');
      expect(result.styleDescription.photo, '50mm f/1.8');
      expect(result.styleDescription.colorPalette, <String>['#FFFFFF']);
      expect(result.highLevelDescription, 'a cat');
    });
  });
}
