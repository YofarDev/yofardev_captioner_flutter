import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/caption_search/data/services/autocomplete_engine.dart';

void main() {
  group('AutocompleteEngine', () {
    late AutocompleteEngine engine;
    late Set<String> tags;
    late Set<String> mediums;

    setUp(() {
      tags = <String>{'sunset', 'beach', 'sunrise', 'mountain'};
      mediums = <String>{'photograph', 'painting', 'illustration'};
      engine = AutocompleteEngine(
        getUniqueTags: () => tags,
        getUniqueMediums: () => mediums,
      );
    });

    group('filter name suggestions', () {
      test('typing : suggests all filter names', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':',
          1,
        );

        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every(
            (AutocompleteSuggestion s) => s is FilterNameSuggestion,
          ),
          isTrue,
        );
        // Verify known filter names are present
        final List<String> names = suggestions
            .cast<FilterNameSuggestion>()
            .map((FilterNameSuggestion s) => s.name)
            .toList();
        expect(names, contains('tag'));
        expect(names, contains('has'));
        expect(names, contains('medium'));
        expect(names, contains('desc'));
      });

      test('typing :t suggests filter names starting with t', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':t',
          2,
        );

        expect(suggestions, isNotEmpty);
        final List<String> names = suggestions
            .cast<FilterNameSuggestion>()
            .map((FilterNameSuggestion s) => s.name)
            .toList();
        expect(names, hasLength(1));
        expect(names.first, 'tag');
      });

      test(': followed by non-alpha does not suggest filter names', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':1',
          2,
        );
        expect(suggestions, isEmpty);
      });
    });

    group('tag value suggestions', () {
      test('typing :tag: suggests all tag values', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':tag:',
          5,
        );

        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every(
            (AutocompleteSuggestion s) => s is TagValueSuggestion,
          ),
          isTrue,
        );
        final List<String> values = suggestions
            .cast<TagValueSuggestion>()
            .map((TagValueSuggestion s) => s.value)
            .toList();
        expect(values, containsAll(<String>['sunset', 'beach', 'mountain']));
      });

      test('typing :tag:sun suggests tag values matching sun', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':tag:sun',
          8,
        );

        expect(suggestions, hasLength(2));
        final List<String> values = suggestions
            .cast<TagValueSuggestion>()
            .map((TagValueSuggestion s) => s.value)
            .toList();
        expect(values, containsAll(<String>['sunset', 'sunrise']));
      });

      test(':tag: is case-insensitive when matching', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':tag:SUN',
          8,
        );

        expect(suggestions, hasLength(2));
      });
    });

    group('has type suggestions', () {
      test('typing :has:b suggests only bbox', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':has:b',
          6,
        );

        expect(suggestions, hasLength(1));
        final HasTypeSuggestion suggestion =
            suggestions.single as HasTypeSuggestion;
        expect(suggestion.type, 'bbox');
      });

      test('typing :has: suggests text, obj, bbox', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':has:',
          5,
        );

        expect(suggestions, hasLength(3));
        expect(
          suggestions.every(
            (AutocompleteSuggestion s) => s is HasTypeSuggestion,
          ),
          isTrue,
        );
        final List<String> types = suggestions
            .cast<HasTypeSuggestion>()
            .map((HasTypeSuggestion s) => s.type)
            .toList();
        expect(types, containsAll(<String>['text', 'obj', 'bbox']));
      });
    });

    group('medium value suggestions', () {
      test('typing :medium: suggests all medium values', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':medium:',
          8,
        );

        expect(suggestions, isNotEmpty);
        expect(
          suggestions.every(
            (AutocompleteSuggestion s) => s is MediumValueSuggestion,
          ),
          isTrue,
        );
        final List<String> values = suggestions
            .cast<MediumValueSuggestion>()
            .map((MediumValueSuggestion s) => s.value)
            .toList();
        expect(
          values,
          containsAll(<String>['photograph', 'painting', 'illustration']),
        );
      });

      test('typing :medium:pho suggests medium values matching pho', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':medium:pho',
          11,
        );

        expect(suggestions, hasLength(1));
        final MediumValueSuggestion suggestion =
            suggestions.single as MediumValueSuggestion;
        expect(suggestion.value, 'photograph');
      });
    });

    group('edge cases — no suggestions', () {
      test('cursor at random position in plain text', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          'hello world',
          5,
        );
        expect(suggestions, isEmpty);
      });

      test('inside closed filter :tag:sunset:x (x after closing colon)', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':tag:sunset:x',
          13,
        );
        expect(suggestions, isEmpty);
      });

      test('plain text alone suggests nothing', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          'sunset',
          6,
        );
        expect(suggestions, isEmpty);
      });

      test('empty query suggests nothing', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          '',
          0,
        );
        expect(suggestions, isEmpty);
      });

      test(':: (double colon) suggests nothing', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          '::',
          2,
        );
        expect(suggestions, isEmpty);
      });

      test(
        ':tag:foo:sunset (closed tag filter then text) suggests nothing',
        () {
          final List<AutocompleteSuggestion> suggestions = engine
              .getSuggestions(':tag:foo:sunset', 15);
          expect(suggestions, isEmpty);
        },
      );
    });

    group('cursor in the middle of text', () {
      test('cursor before filter does not trigger suggestions', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          'hello :tag:sunset',
          6,
        );
        expect(suggestions, isEmpty);
      });

      test('cursor after colon with numbers suggests nothing', () {
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          'hello:123',
          9,
        );
        expect(suggestions, isEmpty);
      });
    });

    group('getUniqueTags and getUniqueMediums callbacks', () {
      test('empty tags set returns empty tag suggestions', () {
        tags.clear();
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':tag:',
          5,
        );
        expect(suggestions, isEmpty);
      });

      test('empty mediums set returns empty medium suggestions', () {
        mediums.clear();
        final List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':medium:',
          8,
        );
        expect(suggestions, isEmpty);
      });

      test('callbacks are called fresh each time (mutable set)', () {
        // First call: tags has 4 items
        List<AutocompleteSuggestion> suggestions = engine.getSuggestions(
          ':tag:',
          5,
        );
        expect(suggestions, hasLength(4));

        // Modify the underlying set
        tags.add('night');
        tags.add('cityscape');

        // Second call: should pick up the new items
        suggestions = engine.getSuggestions(':tag:', 5);
        expect(suggestions, hasLength(6));
      });
    });
  });
}
