import 'dart:io';

import '../../../image_operations/data/utils/image_utils.dart';

/// Abstraction over [ImageUtils.resizeImageIfNecessary] for testability.
class ImageResizer {
  const ImageResizer();

  Future<File> resizeImageIfNecessary(File imageFile) =>
      ImageUtils.resizeImageIfNecessary(imageFile);
}
