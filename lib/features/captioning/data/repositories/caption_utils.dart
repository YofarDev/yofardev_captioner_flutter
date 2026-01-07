import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../image_list/data/models/app_image.dart';

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
  List<AppImage> searchAndReplace(
    String search,
    String replace,
    List<AppImage> images,
  ) {
    final List<AppImage> updatedImages = <AppImage>[];
    for (final AppImage image in images) {
      if (image.caption.contains(search)) {
        final String captionPath = p.setExtension(image.image.path, '.txt');
        final File captionFile = File(captionPath);
        final String newCaption = image.caption.replaceAll(search, replace);
        captionFile.writeAsStringSync(newCaption);
        updatedImages.add(
          image.copyWith(caption: newCaption, isCaptionEdited: true),
        );
      } else {
        updatedImages.add(image);
      }
    }
    return updatedImages;
  }

  /// Counts the total occurrences of a [search] string across all captions in a list of [AppImage]s.
  ///
  /// [search]: The string to count occurrences of.
  /// [images]: The list of [AppImage]s whose captions will be searched.
  /// Returns the total count of occurrences. Returns 0 if [search] is empty.
  OccurrenceResult countOccurrences(String search, List<AppImage> images) {
    if (search.isEmpty) {
      return const OccurrenceResult(count: 0, fileNames: <String>[]);
    }
    int count = 0;
    final List<String> fileNames = <String>[];
    for (final AppImage image in images) {
      final int matches = search.allMatches(image.caption).length;
      if (matches > 0) {
        count += matches;
        fileNames.add(p.basename(image.image.path));
      }
    }
    return OccurrenceResult(count: count, fileNames: fileNames);
  }
}

class OccurrenceResult {
  const OccurrenceResult({required this.count, required this.fileNames});

  final int count;
  final List<String> fileNames;
}
