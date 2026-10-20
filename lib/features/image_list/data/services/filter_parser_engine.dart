import '../../../../core/models/app_image.dart';
import '../../../caption_search/caption_search.dart';
import '../../domain/services/caption_session_service.dart';

/// Data-layer implementation of the session's [CaptionFilterEngine] port on
/// top of caption_search's [FilterParser].
class FilterParserCaptionEngine implements CaptionFilterEngine {
  const FilterParserCaptionEngine();

  /// Returns the filtered list of images based on the current search query.
  ///
  /// Supports both plain text search and structured filter expressions
  /// (e.g. `:has:text:`, `:medium:photograph:`). Filters are parsed via
  /// [FilterParser] and all components combine with AND logic.
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) {
    if (query.isEmpty) {
      return images;
    }

    final ParsedFilterQuery parsedQuery = FilterParser.parse(query);

    // No filters and no text — return all
    if (parsedQuery.filters.isEmpty && parsedQuery.plainTextQuery.isEmpty) {
      return images;
    }

    return images.where((AppImage image) {
      final String captionText = image.captions[category]?.text ?? '';

      // Plain text component (respects case sensitivity)
      if (parsedQuery.plainTextQuery.isNotEmpty) {
        final String needle = caseSensitive
            ? parsedQuery.plainTextQuery
            : parsedQuery.plainTextQuery.toLowerCase();
        final String searchCaption = caseSensitive
            ? captionText
            : captionText.toLowerCase();
        if (!searchCaption.contains(needle)) {
          return false;
        }
      }

      // Structured filter expressions (AND logic)
      for (final FilterExpression filter in parsedQuery.filters) {
        if (!filter.evaluate(
          FilterContext(captionText: captionText, tags: image.tags),
        )) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
