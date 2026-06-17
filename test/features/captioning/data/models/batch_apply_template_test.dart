import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/batch_apply_template.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';

void main() {
  group('BatchApplyTemplate', () {
    test('mergeInto overwrites specified fields, keeps others', () {
      final template = BatchApplyTemplate(
        highLevelDescription: 'new description',
        aesthetics: 'cinematic',
      );

      final existing = IdeogramCaption(
        highLevelDescription: 'old description',
        styleDescription: IdeogramStyleDescription(
          aesthetics: 'ethereal',
          lighting: 'soft',
          medium: 'photograph',
          photo: '35mm',
          colorPalette: <String>['#FF0000'],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: 'old background',
          elements: <IdeogramElement>[],
        ),
      );

      final result = template.mergeInto(existing);

      expect(result.highLevelDescription, 'new description');
      expect(result.styleDescription.aesthetics, 'cinematic');
      expect(result.styleDescription.lighting, 'soft');
      expect(result.compositionalDeconstruction.background, 'old background');
    });

    test('mergeInto does not touch null template fields', () {
      final template = BatchApplyTemplate();

      final existing = IdeogramCaption(
        highLevelDescription: 'desc',
        styleDescription: IdeogramStyleDescription(
          aesthetics: 'aes',
          lighting: 'light',
          medium: 'oil_on_canvas',
          artStyle: 'impressionism',
          colorPalette: <String>['#000000'],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: 'bg',
          elements: <IdeogramElement>[],
        ),
      );

      final result = template.mergeInto(existing);

      expect(result.highLevelDescription, 'desc');
      expect(result.styleDescription.aesthetics, 'aes');
      expect(result.styleDescription.medium, 'oil_on_canvas');
      expect(result.styleDescription.artStyle, 'impressionism');
      expect(result.compositionalDeconstruction.background, 'bg');
    });

    test('toMinimalCaption creates caption with only template fields', () {
      final template = BatchApplyTemplate(
        highLevelDescription: 'desc',
        aesthetics: 'cinematic',
      );

      final result = template.toMinimalCaption();

      expect(result.highLevelDescription, 'desc');
      expect(result.styleDescription.aesthetics, 'cinematic');
      expect(result.styleDescription.medium, 'photograph');
    });

    test('toMinimalCaption with all fields', () {
      final template = BatchApplyTemplate(
        highLevelDescription: 'desc',
        aesthetics: 'ethereal',
        lighting: 'soft',
        medium: 'oil_on_canvas',
        artStyle: 'impressionism',
        background: 'a forest',
      );

      final result = template.toMinimalCaption();

      expect(result.highLevelDescription, 'desc');
      expect(result.styleDescription.aesthetics, 'ethereal');
      expect(result.styleDescription.lighting, 'soft');
      expect(result.styleDescription.medium, 'oil_on_canvas');
      expect(result.styleDescription.artStyle, 'impressionism');
      expect(result.compositionalDeconstruction.background, 'a forest');
      expect(result.compositionalDeconstruction.elements, isEmpty);
    });
  });
}
