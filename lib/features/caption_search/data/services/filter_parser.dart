import '../models/filter_query.dart';

/// Parses a raw search query string into structured filter expressions
/// and a plain text component.
///
/// Filter syntax: `:filter_name:arg:arg:` — always starts and ends with `:`.
/// Unknown `:` patterns are treated as plain text.
class FilterParser {
  /// Known filter name keywords.
  static const Set<String> _knownFilters = <String>{
    'has',
    'elements',
    'medium',
    'desc',
    'style',
    'bg',
    'element',
    'color',
    'structured',
    'plain',
    'nocaption',
    'dupbbox',
    'tag',
    'notag',
  };

  /// Flag-only filters (no arguments between name and closing `:`).
  static const Set<String> _flagFilters = <String>{
    'structured',
    'plain',
    'nocaption',
    'notag',
  };

  /// Parses [query] into a [ParsedFilterQuery].
  ///
  /// Scans left-to-right. When `:` is followed by a known filter name and
  /// another `:`, the filter expression is consumed. Unmatched text becomes
  /// the plain text component.
  static ParsedFilterQuery parse(String query) {
    final List<FilterExpression> filters = <FilterExpression>[];
    final StringBuffer plainText = StringBuffer();

    int pos = 0;
    while (pos < query.length) {
      if (query[pos] == ':') {
        final _ParseResult? result = _tryParseFilter(query, pos);
        if (result != null) {
          filters.add(result.filter);
          pos = result.endIndex;
          continue;
        }
      }
      plainText.write(query[pos]);
      pos++;
    }

    return ParsedFilterQuery(
      filters: filters,
      plainTextQuery: plainText.toString().trim(),
    );
  }

  /// Attempts to parse a filter expression starting at [pos].
  ///
  /// Returns `null` if no valid filter is found at this position.
  static _ParseResult? _tryParseFilter(String query, int pos) {
    if (pos >= query.length || query[pos] != ':') return null;

    // Find the filter name between first and second colon
    final int nameStart = pos + 1;
    final int nameEnd = _indexOf(query, ':', nameStart);
    if (nameEnd == -1) return null;

    final String name = query.substring(nameStart, nameEnd);

    if (!_knownFilters.contains(name)) return null;

    // Flag filters: :structured:, :plain:, :nocaption:
    if (_flagFilters.contains(name)) {
      final FilterExpression filter = _createFlagFilter(name);
      return _ParseResult(filter: filter, endIndex: nameEnd + 1);
    }

    // :has:type: — one argument
    if (name == 'has') {
      final int argEnd = _indexOf(query, ':', nameEnd + 1);
      if (argEnd == -1) return null;
      final String arg = query
          .substring(nameEnd + 1, argEnd)
          .trim()
          .toLowerCase();
      if (arg == 'text' || arg == 'obj') {
        return _ParseResult(
          filter: HasTypeFilter(elementType: arg),
          endIndex: argEnd + 1,
        );
      }
      if (arg == 'bbox') {
        return _ParseResult(
          filter: const HasBboxFilter(),
          endIndex: argEnd + 1,
        );
      }
      // Unknown has arg — not a valid filter
      return null;
    }

    // :dupbbox: or :dupbbox:threshold: — optional IoU threshold argument
    if (name == 'dupbbox') {
      return _parseDuplicateBbox(query, nameEnd);
    }

    // :elements:N: or :elements:>N: or :elements:>=N:
    if (name == 'elements') {
      final int argEnd = _indexOf(query, ':', nameEnd + 1);
      if (argEnd == -1) return null;
      final String arg = query.substring(nameEnd + 1, argEnd).trim();
      final ElementCountFilter? filter = _parseElementCount(arg);
      if (filter != null) {
        return _ParseResult(filter: filter, endIndex: argEnd + 1);
      }
      return null;
    }

    // :medium:value:
    if (name == 'medium') {
      final int argEnd = _indexOf(query, ':', nameEnd + 1);
      if (argEnd == -1) return null;
      final String arg = query.substring(nameEnd + 1, argEnd).trim();
      return _ParseResult(
        filter: MediumFilter(medium: arg),
        endIndex: argEnd + 1,
      );
    }

    // :desc:pattern:, :style:pattern:, :bg:pattern:, :element:pattern:
    if (name == 'desc' ||
        name == 'style' ||
        name == 'bg' ||
        name == 'element') {
      final int argEnd = _indexOf(query, ':', nameEnd + 1);
      if (argEnd == -1) return null;
      final String arg = query.substring(nameEnd + 1, argEnd).trim();
      final FilterExpression filter = switch (name) {
        'desc' => DescriptionFilter(pattern: arg),
        'style' => StyleFilter(pattern: arg),
        'bg' => BackgroundFilter(pattern: arg),
        'element' => ElementDescFilter(pattern: arg),
        _ => throw StateError('unreachable'),
      };
      return _ParseResult(filter: filter, endIndex: argEnd + 1);
    }

    // :color:#HEX:
    if (name == 'color') {
      final int argEnd = _indexOf(query, ':', nameEnd + 1);
      if (argEnd == -1) return null;
      final String arg = query.substring(nameEnd + 1, argEnd).trim();
      return _ParseResult(
        filter: ColorFilter(hexColor: arg),
        endIndex: argEnd + 1,
      );
    }

    // :tag:value:
    if (name == 'tag') {
      final int argEnd = _indexOf(query, ':', nameEnd + 1);
      if (argEnd == -1) return null;
      final String arg = query.substring(nameEnd + 1, argEnd).trim();
      if (arg.isEmpty) return null;
      return _ParseResult(
        filter: TagFilter(tag: arg),
        endIndex: argEnd + 1,
      );
    }

    return null;
  }

  /// Creates a flag-only filter from its name.
  static FilterExpression _createFlagFilter(String name) {
    return switch (name) {
      'structured' => const IsStructuredFilter(),
      'plain' => const IsPlainFilter(),
      'nocaption' => const NoCaptionFilter(),
      'notag' => const NoTagFilter(),
      _ => throw ArgumentError('Unknown flag filter: $name'),
    };
  }

  /// Parses element count expressions: "3", ">2", ">=3".
  static ElementCountFilter? _parseElementCount(String arg) {
    final RegExp equalRe = RegExp(r'^(\d+)$');
    final RegExp gtRe = RegExp(r'^>(\d+)$');
    final RegExp gteRe = RegExp(r'^>=(\d+)$');

    RegExpMatch? match = equalRe.firstMatch(arg);
    if (match != null) {
      return ElementCountFilter(
        count: int.parse(match.group(1)!),
        operator: '=',
      );
    }

    match = gteRe.firstMatch(arg);
    if (match != null) {
      return ElementCountFilter(
        count: int.parse(match.group(1)!),
        operator: '>=',
      );
    }

    match = gtRe.firstMatch(arg);
    if (match != null) {
      return ElementCountFilter(
        count: int.parse(match.group(1)!),
        operator: '>',
      );
    }

    return null;
  }

  /// Parses `:dupbbox:` (flag form) or `:dupbbox:N:` (threshold form).
  ///
  /// [nameEnd] is the index of the `:` following the `dupbbox` name.
  /// Returns `null` only when the closing `:` is missing entirely; an invalid
  /// threshold falls back to the default-threshold flag form.
  static _ParseResult? _parseDuplicateBbox(String query, int nameEnd) {
    // Flag form: `:dupbbox:` — nothing valid follows the closing `:`.
    if (nameEnd + 1 >= query.length || query[nameEnd + 1] == ':') {
      return _ParseResult(
        filter: const DuplicateBboxFilter(),
        endIndex: nameEnd + 1,
      );
    }

    // Argument form: look for `:dupbbox:VALUE:` and try to parse VALUE.
    final int argEnd = _indexOf(query, ':', nameEnd + 1);
    if (argEnd == -1) {
      // No closing `:` — treat as flag form, leave the rest as plain text.
      return _ParseResult(
        filter: const DuplicateBboxFilter(),
        endIndex: nameEnd + 1,
      );
    }

    final String arg = query.substring(nameEnd + 1, argEnd).trim();
    final double? threshold = double.tryParse(arg);
    if (threshold != null && threshold > 0 && threshold <= 1) {
      return _ParseResult(
        filter: DuplicateBboxFilter(threshold: threshold),
        endIndex: argEnd + 1,
      );
    }

    // Invalid threshold — fall back to flag form, consume just `:dupbbox:`.
    return _ParseResult(
      filter: const DuplicateBboxFilter(),
      endIndex: nameEnd + 1,
    );
  }

  /// Finds the index of [char] in [str] starting at [from].
  /// Returns `-1` if not found.
  static int _indexOf(String str, String char, int from) {
    for (int i = from; i < str.length; i++) {
      if (str[i] == char) return i;
    }
    return -1;
  }
}

/// Internal result of a filter parse attempt.
class _ParseResult {
  const _ParseResult({required this.filter, required this.endIndex});

  final FilterExpression filter;
  final int endIndex;
}
