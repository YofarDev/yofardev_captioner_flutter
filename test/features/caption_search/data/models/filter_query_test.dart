import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/caption_search/data/models/filter_query.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';

void main() {
  // Sample Ideogram JSON for testing
  const String sampleIdeogramJson =
      '{"high_level_description":"A cat sitting on a forest path at sunset","style_description":{"aesthetics":"minimalist","lighting":"golden hour","medium":"photograph","photo":"Canon EOS R5","color_palette":["#8B4513","#228B22","#FFD700"]},"compositional_deconstruction":{"background":"dense forest with tall trees","elements":[{"type":"obj","bbox":[100,200,500,600],"desc":"orange tabby cat sitting","color_palette":["#FF8C00"]},{"type":"text","bbox":[50,50,150,300],"desc":"a sign saying hello","text":"hello"},{"type":"obj","desc":"a rock on the path"}]}}';

  const String plainTextCaption = 'A beautiful sunset over the ocean';

  group('HasTypeFilter', () {
    test('matches text elements', () {
      const HasTypeFilter filter = HasTypeFilter(elementType: 'text');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
      expect(filter.evaluate(plainTextCaption), isFalse);
      expect(filter.evaluate(''), isFalse);
    });

    test('matches obj elements', () {
      const HasTypeFilter filter = HasTypeFilter(elementType: 'obj');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match when element type absent', () {
      const HasTypeFilter filter = HasTypeFilter(elementType: 'text');
      const String noTextJson =
          '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","desc":"thing"}]}}';
      expect(filter.evaluate(noTextJson), isFalse);
    });
  });

  group('HasBboxFilter', () {
    test('matches when bbox present', () {
      const HasBboxFilter filter = HasBboxFilter();
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for plain text', () {
      const HasBboxFilter filter = HasBboxFilter();
      expect(filter.evaluate(plainTextCaption), isFalse);
    });

    test('no match when no bboxes', () {
      const HasBboxFilter filter = HasBboxFilter();
      const String noBboxJson =
          '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","desc":"thing"}]}}';
      expect(filter.evaluate(noBboxJson), isFalse);
    });
  });

  group('ElementCountFilter', () {
    test('matches exact count', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 3,
        operator: '=',
      );
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('matches greater than', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 2,
        operator: '>',
      );
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('matches greater or equal', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 3,
        operator: '>=',
      );
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for wrong count', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 5,
        operator: '=',
      );
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });

    test('no match for plain text', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 3,
        operator: '=',
      );
      expect(filter.evaluate(plainTextCaption), isFalse);
    });
  });

  group('MediumFilter', () {
    test('matches photograph medium', () {
      const MediumFilter filter = MediumFilter(medium: 'photograph');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for different medium', () {
      const MediumFilter filter = MediumFilter(medium: 'oil_painting');
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });

    test('case insensitive', () {
      const MediumFilter filter = MediumFilter(medium: 'Photograph');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });
  });

  group('DescriptionFilter', () {
    test('matches pattern in description', () {
      const DescriptionFilter filter = DescriptionFilter(pattern: 'cat');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('case insensitive', () {
      const DescriptionFilter filter = DescriptionFilter(pattern: 'Cat');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for absent pattern', () {
      const DescriptionFilter filter = DescriptionFilter(pattern: 'dog');
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });
  });

  group('StyleFilter', () {
    test('matches aesthetics field', () {
      const StyleFilter filter = StyleFilter(pattern: 'minimalist');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('matches lighting field', () {
      const StyleFilter filter = StyleFilter(pattern: 'golden');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for absent pattern', () {
      const StyleFilter filter = StyleFilter(pattern: 'dramatic');
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });
  });

  group('BackgroundFilter', () {
    test('matches pattern in background', () {
      const BackgroundFilter filter = BackgroundFilter(pattern: 'forest');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for absent pattern', () {
      const BackgroundFilter filter = BackgroundFilter(pattern: 'ocean');
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });
  });

  group('ElementDescFilter', () {
    test('matches pattern in element desc', () {
      const ElementDescFilter filter = ElementDescFilter(pattern: 'cat');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('matches pattern in element text field', () {
      const ElementDescFilter filter = ElementDescFilter(pattern: 'hello');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for absent pattern', () {
      const ElementDescFilter filter = ElementDescFilter(pattern: 'dog');
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });
  });

  group('ColorFilter', () {
    test('matches color in style palette', () {
      const ColorFilter filter = ColorFilter(hexColor: '#8B4513');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('matches color in element palette', () {
      const ColorFilter filter = ColorFilter(hexColor: '#FF8C00');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('case insensitive hex', () {
      const ColorFilter filter = ColorFilter(hexColor: '#8b4513');
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for absent color', () {
      const ColorFilter filter = ColorFilter(hexColor: '#000000');
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });
  });

  group('IsStructuredFilter', () {
    test('matches Ideogram JSON', () {
      const IsStructuredFilter filter = IsStructuredFilter();
      expect(filter.evaluate(sampleIdeogramJson), isTrue);
    });

    test('no match for plain text', () {
      const IsStructuredFilter filter = IsStructuredFilter();
      expect(filter.evaluate(plainTextCaption), isFalse);
    });

    test('no match for empty', () {
      const IsStructuredFilter filter = IsStructuredFilter();
      expect(filter.evaluate(''), isFalse);
    });
  });

  group('IsPlainFilter', () {
    test('matches plain text', () {
      const IsPlainFilter filter = IsPlainFilter();
      expect(filter.evaluate(plainTextCaption), isTrue);
    });

    test('no match for Ideogram JSON', () {
      const IsPlainFilter filter = IsPlainFilter();
      expect(filter.evaluate(sampleIdeogramJson), isFalse);
    });

    test('no match for empty', () {
      const IsPlainFilter filter = IsPlainFilter();
      expect(filter.evaluate(''), isFalse);
    });
  });

  group('NoCaptionFilter', () {
    test('matches empty string', () {
      const NoCaptionFilter filter = NoCaptionFilter();
      expect(filter.evaluate(''), isTrue);
    });

    test('matches whitespace only', () {
      const NoCaptionFilter filter = NoCaptionFilter();
      expect(filter.evaluate('   '), isTrue);
    });

    test('no match for actual caption', () {
      const NoCaptionFilter filter = NoCaptionFilter();
      expect(filter.evaluate(plainTextCaption), isFalse);
    });
  });

  group('tryParseCaption', () {
    test('parses valid Ideogram JSON', () {
      final IdeogramCaption? caption = FilterExpression.tryParseCaption(
        sampleIdeogramJson,
      );
      expect(caption, isNotNull);
      expect(caption!.highLevelDescription, contains('cat'));
    });

    test('returns null for plain text', () {
      final IdeogramCaption? caption = FilterExpression.tryParseCaption(
        plainTextCaption,
      );
      expect(caption, isNull);
    });

    test('returns null for empty string', () {
      final IdeogramCaption? caption = FilterExpression.tryParseCaption('');
      expect(caption, isNull);
    });

    test('returns null for invalid JSON', () {
      final IdeogramCaption? caption = FilterExpression.tryParseCaption(
        '{invalid}',
      );
      expect(caption, isNull);
    });
  });
}
