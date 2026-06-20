import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/caption_search/data/models/filter_query.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';

void main() {
  FilterContext ctx(String caption) =>
      FilterContext(captionText: caption, tags: const <String>[]);

  // Sample Ideogram JSON for testing
  const String sampleIdeogramJson =
      '{"high_level_description":"A cat sitting on a forest path at sunset","style_description":{"aesthetics":"minimalist","lighting":"golden hour","photo":"Canon EOS R5","medium":"photograph","color_palette":["#8B4513","#228B22","#FFD700"]},"compositional_deconstruction":{"background":"dense forest with tall trees","elements":[{"type":"obj","bbox":[100,200,500,600],"desc":"orange tabby cat sitting","color_palette":["#FF8C00"]},{"type":"text","bbox":[50,50,150,300],"desc":"a sign saying hello","text":"hello"},{"type":"obj","desc":"a rock on the path"}]}}';

  const String plainTextCaption = 'A beautiful sunset over the ocean';

  group('HasTypeFilter', () {
    test('matches text elements', () {
      const HasTypeFilter filter = HasTypeFilter(elementType: 'text');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
      expect(filter.evaluate(ctx(plainTextCaption)), isFalse);
      expect(filter.evaluate(ctx('')), isFalse);
    });

    test('matches obj elements', () {
      const HasTypeFilter filter = HasTypeFilter(elementType: 'obj');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match when element type absent', () {
      const HasTypeFilter filter = HasTypeFilter(elementType: 'text');
      const String noTextJson =
          '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","desc":"thing"}]}}';
      expect(filter.evaluate(ctx(noTextJson)), isFalse);
    });
  });

  group('HasBboxFilter', () {
    test('matches when bbox present', () {
      const HasBboxFilter filter = HasBboxFilter();
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for plain text', () {
      const HasBboxFilter filter = HasBboxFilter();
      expect(filter.evaluate(ctx(plainTextCaption)), isFalse);
    });

    test('no match when no bboxes', () {
      const HasBboxFilter filter = HasBboxFilter();
      const String noBboxJson =
          '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","desc":"thing"}]}}';
      expect(filter.evaluate(ctx(noBboxJson)), isFalse);
    });
  });

  group('DuplicateBboxFilter', () {
    // Two identical bboxes — IoU = 1.0
    const String identicalBboxesJson =
        '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","bbox":[100,100,500,500],"desc":"a"},{"type":"obj","bbox":[100,100,500,500],"desc":"b"}]}}';

    // Two near-duplicate bboxes (slightly offset) — IoU ≈ 0.82
    const String nearDuplicateBboxesJson =
        '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","bbox":[100,100,500,500],"desc":"a"},{"type":"obj","bbox":[120,120,520,520],"desc":"b"}]}}';

    // Two moderately overlapping bboxes — IoU ≈ 0.39
    const String moderateOverlapBboxesJson =
        '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","bbox":[100,100,500,500],"desc":"a"},{"type":"obj","bbox":[200,200,600,600],"desc":"b"}]}}';

    // Two slightly overlapping bboxes — IoU ≈ 0.059
    const String slightlyOverlappingBboxesJson =
        '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","bbox":[0,0,300,300],"desc":"a"},{"type":"obj","bbox":[200,200,500,500],"desc":"b"}]}}';

    // Two non-overlapping bboxes — IoU = 0
    const String disjointBboxesJson =
        '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","bbox":[0,0,100,100],"desc":"a"},{"type":"obj","bbox":[500,500,600,600],"desc":"b"}]}}';

    // Only one bbox
    const String singleBboxJson =
        '{"high_level_description":"test","style_description":{"aesthetics":"a","lighting":"b","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"bg","elements":[{"type":"obj","bbox":[100,100,500,500],"desc":"a"}]}}';

    test('matches identical bboxes', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(identicalBboxesJson)), isTrue);
    });

    test('matches near-duplicate bboxes (IoU > default 0.7)', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(nearDuplicateBboxesJson)), isTrue);
    });

    test('does not match moderate overlap (IoU < default 0.7)', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(moderateOverlapBboxesJson)), isFalse);
    });

    test('matches moderate overlap with lower threshold', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter(threshold: 0.3);
      expect(filter.evaluate(ctx(moderateOverlapBboxesJson)), isTrue);
    });

    test('does not match slightly overlapping bboxes (IoU < default 0.7)', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(slightlyOverlappingBboxesJson)), isFalse);
    });

    test('matches slightly overlapping bboxes with lower threshold', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter(threshold: 0.05);
      expect(filter.evaluate(ctx(slightlyOverlappingBboxesJson)), isTrue);
    });

    test('does not match disjoint bboxes', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(disjointBboxesJson)), isFalse);
    });

    test('does not match when only one bbox', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(singleBboxJson)), isFalse);
    });

    test('does not match plain text', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx(plainTextCaption)), isFalse);
    });

    test('does not match empty string', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.evaluate(ctx('')), isFalse);
    });

    test('iou() returns 1.0 for identical boxes', () {
      expect(
        DuplicateBboxFilter.iou(
          <int>[100, 100, 500, 500],
          <int>[100, 100, 500, 500],
        ),
        equals(1.0),
      );
    });

    test('iou() returns 0.0 for disjoint boxes', () {
      expect(
        DuplicateBboxFilter.iou(
          <int>[0, 0, 100, 100],
          <int>[500, 500, 600, 600],
        ),
        equals(0.0),
      );
    });

    test('iou() handles touching (zero-area intersection) boxes', () {
      // Adjacent, no overlap — interY2 == interY1
      expect(
        DuplicateBboxFilter.iou(<int>[0, 0, 100, 100], <int>[100, 0, 200, 100]),
        equals(0.0),
      );
    });

    test('default threshold is 0.7', () {
      const DuplicateBboxFilter filter = DuplicateBboxFilter();
      expect(filter.threshold, equals(0.7));
    });
  });

  group('ElementCountFilter', () {
    test('matches exact count', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 3,
        operator: '=',
      );
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('matches greater than', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 2,
        operator: '>',
      );
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('matches greater or equal', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 3,
        operator: '>=',
      );
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for wrong count', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 5,
        operator: '=',
      );
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });

    test('no match for plain text', () {
      const ElementCountFilter filter = ElementCountFilter(
        count: 3,
        operator: '=',
      );
      expect(filter.evaluate(ctx(plainTextCaption)), isFalse);
    });
  });

  group('MediumFilter', () {
    test('matches photograph medium', () {
      const MediumFilter filter = MediumFilter(medium: 'photograph');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for different medium', () {
      const MediumFilter filter = MediumFilter(medium: 'oil_painting');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });

    test('case insensitive', () {
      const MediumFilter filter = MediumFilter(medium: 'Photograph');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });
  });

  group('DescriptionFilter', () {
    test('matches pattern in description', () {
      const DescriptionFilter filter = DescriptionFilter(pattern: 'cat');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('case insensitive', () {
      const DescriptionFilter filter = DescriptionFilter(pattern: 'Cat');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for absent pattern', () {
      const DescriptionFilter filter = DescriptionFilter(pattern: 'dog');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });
  });

  group('StyleFilter', () {
    test('matches aesthetics field', () {
      const StyleFilter filter = StyleFilter(pattern: 'minimalist');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('matches lighting field', () {
      const StyleFilter filter = StyleFilter(pattern: 'golden');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for absent pattern', () {
      const StyleFilter filter = StyleFilter(pattern: 'dramatic');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });
  });

  group('BackgroundFilter', () {
    test('matches pattern in background', () {
      const BackgroundFilter filter = BackgroundFilter(pattern: 'forest');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for absent pattern', () {
      const BackgroundFilter filter = BackgroundFilter(pattern: 'ocean');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });
  });

  group('ElementDescFilter', () {
    test('matches pattern in element desc', () {
      const ElementDescFilter filter = ElementDescFilter(pattern: 'cat');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('matches pattern in element text field', () {
      const ElementDescFilter filter = ElementDescFilter(pattern: 'hello');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for absent pattern', () {
      const ElementDescFilter filter = ElementDescFilter(pattern: 'dog');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });
  });

  group('ColorFilter', () {
    test('matches color in style palette', () {
      const ColorFilter filter = ColorFilter(hexColor: '#8B4513');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('matches color in element palette', () {
      const ColorFilter filter = ColorFilter(hexColor: '#FF8C00');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('case insensitive hex', () {
      const ColorFilter filter = ColorFilter(hexColor: '#8b4513');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for absent color', () {
      const ColorFilter filter = ColorFilter(hexColor: '#000000');
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });
  });

  group('IsStructuredFilter', () {
    test('matches Ideogram JSON', () {
      const IsStructuredFilter filter = IsStructuredFilter();
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isTrue);
    });

    test('no match for plain text', () {
      const IsStructuredFilter filter = IsStructuredFilter();
      expect(filter.evaluate(ctx(plainTextCaption)), isFalse);
    });

    test('no match for empty', () {
      const IsStructuredFilter filter = IsStructuredFilter();
      expect(filter.evaluate(ctx('')), isFalse);
    });
  });

  group('IsPlainFilter', () {
    test('matches plain text', () {
      const IsPlainFilter filter = IsPlainFilter();
      expect(filter.evaluate(ctx(plainTextCaption)), isTrue);
    });

    test('no match for Ideogram JSON', () {
      const IsPlainFilter filter = IsPlainFilter();
      expect(filter.evaluate(ctx(sampleIdeogramJson)), isFalse);
    });

    test('no match for empty', () {
      const IsPlainFilter filter = IsPlainFilter();
      expect(filter.evaluate(ctx('')), isFalse);
    });
  });

  group('NoCaptionFilter', () {
    test('matches empty string', () {
      const NoCaptionFilter filter = NoCaptionFilter();
      expect(filter.evaluate(ctx('')), isTrue);
    });

    test('matches whitespace only', () {
      const NoCaptionFilter filter = NoCaptionFilter();
      expect(filter.evaluate(ctx('   ')), isTrue);
    });

    test('no match for actual caption', () {
      const NoCaptionFilter filter = NoCaptionFilter();
      expect(filter.evaluate(ctx(plainTextCaption)), isFalse);
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
