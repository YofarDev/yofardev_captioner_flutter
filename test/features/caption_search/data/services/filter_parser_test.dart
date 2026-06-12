import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/caption_search/data/models/filter_query.dart';
import 'package:yofardev_captioner/features/caption_search/data/services/filter_parser.dart';

void main() {
  group('FilterParser', () {
    test('empty query returns empty result', () {
      final ParsedFilterQuery result = FilterParser.parse('');
      expect(result.filters, isEmpty);
      expect(result.plainTextQuery, isEmpty);
    });

    test('plain text only returns no filters', () {
      final ParsedFilterQuery result = FilterParser.parse('sunset');
      expect(result.filters, isEmpty);
      expect(result.plainTextQuery, 'sunset');
    });

    test('plain text with spaces is trimmed', () {
      final ParsedFilterQuery result = FilterParser.parse('  hello world  ');
      expect(result.filters, isEmpty);
      expect(result.plainTextQuery, 'hello world');
    });

    group(':has: filter', () {
      test(':has:text: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':has:text:');
        expect(result.filters, hasLength(1));
        expect(result.filters.first, isA<HasTypeFilter>());
        expect((result.filters.first as HasTypeFilter).elementType, 'text');
        expect(result.plainTextQuery, isEmpty);
      });

      test(':has:obj: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':has:obj:');
        expect(result.filters, hasLength(1));
        expect(result.filters.first, isA<HasTypeFilter>());
        expect((result.filters.first as HasTypeFilter).elementType, 'obj');
      });

      test(':has:bbox: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':has:bbox:');
        expect(result.filters, hasLength(1));
        expect(result.filters.first, isA<HasBboxFilter>());
      });
    });

    group(':elements: filter', () {
      test(':elements:3: parses exact count', () {
        final ParsedFilterQuery result = FilterParser.parse(':elements:3:');
        expect(result.filters, hasLength(1));
        final ElementCountFilter filter =
            result.filters.first as ElementCountFilter;
        expect(filter.count, 3);
        expect(filter.operator, '=');
      });

      test(':elements:>2: parses greater than', () {
        final ParsedFilterQuery result = FilterParser.parse(':elements:>2:');
        final ElementCountFilter filter =
            result.filters.first as ElementCountFilter;
        expect(filter.count, 2);
        expect(filter.operator, '>');
      });

      test(':elements:>=3: parses greater or equal', () {
        final ParsedFilterQuery result = FilterParser.parse(':elements:>=3:');
        final ElementCountFilter filter =
            result.filters.first as ElementCountFilter;
        expect(filter.count, 3);
        expect(filter.operator, '>=');
      });
    });

    group('text-content filters', () {
      test(':medium:photograph: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(
          ':medium:photograph:',
        );
        expect(result.filters.first, isA<MediumFilter>());
        expect((result.filters.first as MediumFilter).medium, 'photograph');
      });

      test(':desc:sunset: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':desc:sunset:');
        expect(result.filters.first, isA<DescriptionFilter>());
        expect((result.filters.first as DescriptionFilter).pattern, 'sunset');
      });

      test(':style:dramatic: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':style:dramatic:');
        expect(result.filters.first, isA<StyleFilter>());
      });

      test(':bg:forest: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':bg:forest:');
        expect(result.filters.first, isA<BackgroundFilter>());
      });

      test(':element:cat: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':element:cat:');
        expect(result.filters.first, isA<ElementDescFilter>());
      });

      test(':color:#FF0000: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':color:#FF0000:');
        expect(result.filters.first, isA<ColorFilter>());
        expect((result.filters.first as ColorFilter).hexColor, '#FF0000');
      });
    });

    group('flag filters', () {
      test(':structured: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':structured:');
        expect(result.filters, hasLength(1));
        expect(result.filters.first, isA<IsStructuredFilter>());
      });

      test(':plain: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':plain:');
        expect(result.filters, hasLength(1));
        expect(result.filters.first, isA<IsPlainFilter>());
      });

      test(':nocaption: parses correctly', () {
        final ParsedFilterQuery result = FilterParser.parse(':nocaption:');
        expect(result.filters, hasLength(1));
        expect(result.filters.first, isA<NoCaptionFilter>());
      });
    });

    group('combined queries', () {
      test('plain text + filter', () {
        final ParsedFilterQuery result = FilterParser.parse(
          'sunset :has:text:',
        );
        expect(result.filters, hasLength(1));
        expect(result.plainTextQuery, 'sunset');
      });

      test('multiple filters', () {
        final ParsedFilterQuery result = FilterParser.parse(
          ':has:text: :medium:photograph:',
        );
        expect(result.filters, hasLength(2));
        expect(result.plainTextQuery, isEmpty);
      });

      test('filter + text + filter', () {
        final ParsedFilterQuery result = FilterParser.parse(
          ':has:text: cat :medium:photograph:',
        );
        expect(result.filters, hasLength(2));
        expect(result.plainTextQuery, 'cat');
      });
    });

    group('unknown patterns treated as plain text', () {
      test(':unknown:foo: is plain text', () {
        final ParsedFilterQuery result = FilterParser.parse(':unknown:foo:');
        expect(result.filters, isEmpty);
        expect(result.plainTextQuery, ':unknown:foo:');
      });

      test('colon in regular text (e.g. time) is plain text', () {
        final ParsedFilterQuery result = FilterParser.parse(
          'The time is 3:00 PM',
        );
        expect(result.filters, isEmpty);
        expect(result.plainTextQuery, 'The time is 3:00 PM');
      });

      test('incomplete filter is plain text', () {
        final ParsedFilterQuery result = FilterParser.parse(':has');
        expect(result.filters, isEmpty);
        expect(result.plainTextQuery, ':has');
      });
    });
  });
}
