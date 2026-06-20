import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';

void main() {
  group('IdeogramStyleDescription.toJson key order', () {
    test(
      'photo branch emits aesthetics, lighting, photo, medium, color_palette',
      () {
        const IdeogramStyleDescription style = IdeogramStyleDescription(
          aesthetics: 'cinematic',
          lighting: 'golden hour',
          medium: 'photograph',
          photo: 'Canon EOS R5, 50mm f/1.8',
          colorPalette: <String>['#FFFFFF'],
        );

        expect(style.toJson().keys.toList(), <String>[
          'aesthetics',
          'lighting',
          'photo',
          'medium',
          'color_palette',
        ]);
      },
    );

    test(
      'art branch emits aesthetics, lighting, medium, art_style, color_palette',
      () {
        const IdeogramStyleDescription style = IdeogramStyleDescription(
          aesthetics: 'moody',
          lighting: 'rim light',
          medium: 'oil painting',
          artStyle: 'impasto brushwork',
          colorPalette: <String>['#1A1A1A'],
        );

        expect(style.toJson().keys.toList(), <String>[
          'aesthetics',
          'lighting',
          'medium',
          'art_style',
          'color_palette',
        ]);
      },
    );
  });

  group('IdeogramElement.toJson key order', () {
    test('obj element emits type, bbox, desc, color_palette', () {
      const IdeogramElement element = IdeogramElement(
        type: 'obj',
        bbox: <int>[100, 200, 500, 600],
        desc: 'a red apple on a table',
        colorPalette: <String>['#FF0000'],
      );

      expect(element.toJson().keys.toList(), <String>[
        'type',
        'bbox',
        'desc',
        'color_palette',
      ]);
    });

    test('text element emits type, bbox, text, desc, color_palette', () {
      const IdeogramElement element = IdeogramElement(
        type: 'text',
        bbox: <int>[50, 50, 150, 300],
        text: 'STOP',
        desc: 'a red stop sign',
        colorPalette: <String>['#FF0000'],
      );

      expect(element.toJson().keys.toList(), <String>[
        'type',
        'bbox',
        'text',
        'desc',
        'color_palette',
      ]);
    });
  });
}
