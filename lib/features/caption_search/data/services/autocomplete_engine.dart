import 'package:equatable/equatable.dart';

sealed class AutocompleteSuggestion extends Equatable {
  const AutocompleteSuggestion();
}

class FilterNameSuggestion extends AutocompleteSuggestion {
  const FilterNameSuggestion({required this.name, required this.description});

  final String name;
  final String description;

  @override
  List<Object?> get props => <Object?>[name, description];
}

class TagValueSuggestion extends AutocompleteSuggestion {
  const TagValueSuggestion({required this.value});

  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

class HasTypeSuggestion extends AutocompleteSuggestion {
  const HasTypeSuggestion({required this.type});

  final String type;

  @override
  List<Object?> get props => <Object?>[type];
}

class MediumValueSuggestion extends AutocompleteSuggestion {
  const MediumValueSuggestion({required this.value});

  final String value;

  @override
  List<Object?> get props => <Object?>[value];
}

class AutocompleteEngine {
  AutocompleteEngine({
    required Set<String> Function() getUniqueTags,
    required Set<String> Function() getUniqueMediums,
  })  : _getUniqueTags = getUniqueTags,
        _getUniqueMediums = getUniqueMediums;

  final Set<String> Function() _getUniqueTags;
  final Set<String> Function() _getUniqueMediums;

  static const Map<String, String> _filterNames = <String, String>{
    'tag': 'Filter by tag',
    'has': 'Has element type or bbox',
    'medium': 'Filter by medium',
    'desc': 'Description contains text',
    'style': 'Any style field contains text',
    'bg': 'Background contains text',
    'element': 'Element desc/text contains text',
    'color': 'Color palette contains hex',
    'elements': 'Element count (N, >N, >=N)',
    'dupbbox': 'Duplicate bounding boxes',
    'structured': 'Is structured JSON caption',
    'plain': 'Is plain text caption',
    'nocaption': 'Has no caption',
    'notag': 'Has no tags',
  };

  static const List<String> _hasTypes = <String>['text', 'obj', 'bbox'];

  List<AutocompleteSuggestion> getSuggestions(String query, int cursorPos) {
    final String textBeforeCursor = query.substring(0, cursorPos);
    final String textAfterCursor = query.substring(cursorPos);

    final String? inTag = _extractFilterValue(textBeforeCursor, 'tag');
    if (inTag != null) {
      return _suggestTagValues(inTag);
    }

    final String? inHas = _extractFilterValue(textBeforeCursor, 'has');
    if (inHas != null) {
      if (inHas.isEmpty) {
        return _hasTypes
            .map((String t) => HasTypeSuggestion(type: t))
            .toList();
      }
      final String lower = inHas.toLowerCase();
      return _hasTypes
          .where((String t) => t.toLowerCase().startsWith(lower))
          .map((String t) => HasTypeSuggestion(type: t))
          .toList();
    }

    final String? inMedium = _extractFilterValue(textBeforeCursor, 'medium');
    if (inMedium != null) {
      return _suggestMediumValues(inMedium);
    }

    final String? filterPrefix = _getFilterNamePrefix(
      textBeforeCursor,
      textAfterCursor,
    );
    if (filterPrefix != null) {
      return _suggestFilterNames(filterPrefix);
    }

    return <AutocompleteSuggestion>[];
  }

  /// Returns the partial filter name being typed after `:`, or `null` if
  /// we're not in a filter-name context.
  ///
  /// Handles:
  ///   - `:` → `''` (empty prefix → all filter names)
  ///   - `:t` → `'t'` (partial name → filter)
  ///   - `::` → `null` (just-closed filter)
  String? _getFilterNamePrefix(String before, String after) {
    final int lastColon = before.lastIndexOf(':');
    if (lastColon == -1) return null;

    final String afterLastColon = before.substring(lastColon + 1);

    // After the colon we only accept empty or lowercase-alpha characters
    if (afterLastColon.isNotEmpty &&
        !RegExp(r'^[a-z]+$').hasMatch(afterLastColon)) {
      return null;
    }

    // Don't suggest if we just closed a filter (::)
    if (lastColon > 0 && before[lastColon - 1] == ':') return null;

    return afterLastColon; // empty string or partial filter name
  }

  /// Extracts the value portion inside an open filter like `:tag:VALUE`.
  /// Returns `null` if not inside the specified filter.
  ///
  /// Returns:
  ///   - `''` (empty string) when cursor is right after `:filterName:`
  ///   - The partial value when typing inside an open filter
  ///   - `null` if the filter is already closed or not present
  String? _extractFilterValue(String before, String filterName) {
    final String pattern = ':$filterName:';
    final int lastInstance = before.lastIndexOf(pattern);
    if (lastInstance == -1) return null;

    final int valueStart = lastInstance + pattern.length;
    if (valueStart >= before.length) return ''; // cursor right after :filterName:

    final String value = before.substring(valueStart);
    // If there's a closing `:` in the value, the filter is already closed
    if (value.contains(':')) {
      return null;
    }

    return value;
  }

  List<FilterNameSuggestion> _suggestFilterNames(String prefix) {
    final Iterable<MapEntry<String, String>> entries = _filterNames.entries;
    if (prefix.isEmpty) {
      return entries
          .map((MapEntry<String, String> e) => FilterNameSuggestion(
                name: e.key,
                description: e.value,
              ))
          .toList();
    }
    final String lower = prefix.toLowerCase();
    return entries
        .where(
          (MapEntry<String, String> e) => e.key.toLowerCase().startsWith(lower),
        )
        .map((MapEntry<String, String> e) => FilterNameSuggestion(
              name: e.key,
              description: e.value,
            ))
        .toList();
  }

  List<TagValueSuggestion> _suggestTagValues(String partial) {
    final Set<String> allTags = _getUniqueTags();
    if (partial.isEmpty) {
      return allTags
          .map((String t) => TagValueSuggestion(value: t))
          .toList();
    }
    final String lower = partial.toLowerCase();
    return allTags
        .where((String t) => t.toLowerCase().contains(lower))
        .map((String t) => TagValueSuggestion(value: t))
        .toList();
  }

  List<MediumValueSuggestion> _suggestMediumValues(String partial) {
    final Set<String> allMediums = _getUniqueMediums();
    if (partial.isEmpty) {
      return allMediums
          .map((String m) => MediumValueSuggestion(value: m))
          .toList();
    }
    final String lower = partial.toLowerCase();
    return allMediums
        .where((String m) => m.toLowerCase().contains(lower))
        .map((String m) => MediumValueSuggestion(value: m))
        .toList();
  }
}
