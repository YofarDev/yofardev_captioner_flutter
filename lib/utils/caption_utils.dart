import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/app_image.dart';

/// A utility class for caption-related operations.
///
/// This includes searching and replacing text within captions and counting occurrences of specific strings.
class CaptionUtils {
  /// Performs a search and replace operation on the captions of a list of [AppImage]s.
  ///
  /// [search]: The string to search for within the captions.
  /// [replace]: The string to replace [search] with.
  /// [images]: The list of [AppImage]s whose captions will be modified.
  /// Returns a new list of [AppImage]s with updated captions.
  List<AppImage> searchAndReplace(String search, String replace, List<AppImage> images) {
    final List<AppImage> updatedImages = <AppImage>[];
    for (final AppImage image in images) {
      final String captionPath = p.setExtension(image.image.path, '.txt');
      final File captionFile = File(captionPath);
      final String newCaption = image.caption.replaceAll(search, replace);
      captionFile.writeAsStringSync(newCaption);
      updatedImages.add(image.copyWith(caption: newCaption));
    }
    return updatedImages;
  }

  /// Counts the total occurrences of a [search] string across all captions in a list of [AppImage]s.
  ///
  /// [search]: The string to count occurrences of.
  /// [images]: The list of [AppImage]s whose captions will be searched.
  /// Returns the total count of occurrences. Returns 0 if [search] is empty.
  int countOccurrences(String search, List<AppImage> images) {
    if (search.isEmpty) {
      return 0;
    }
    int count = 0;
    for (final AppImage image in images) {
      count += search.allMatches(image.caption).length;
    }
    return count;
  }
}
