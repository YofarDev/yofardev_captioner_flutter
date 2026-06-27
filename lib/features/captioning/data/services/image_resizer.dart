import 'dart:io';

import '../../../../core/services/cache_service.dart';
import '../../../image_operations/data/utils/image_utils.dart';

/// Abstraction over [ImageUtils.resizeImageIfNecessary] for testability.
///
/// Reads the configurable max dimension from [CacheService] so all VLM-bound
/// images respect the user setting without each caller having to thread it.
class ImageResizer {
  const ImageResizer();

  Future<File> resizeImageIfNecessary(File imageFile) async {
    final int maxDimension = await CacheService.loadMaxImageDimension();
    return ImageUtils.resizeImageIfNecessary(
      imageFile,
      maxDimension: maxDimension,
    );
  }
}
