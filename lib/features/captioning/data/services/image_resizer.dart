import 'dart:io';

import '../../../../core/services/cache_service.dart';
import '../../../../core/utils/image_utils.dart';

/// Abstraction over [ImageUtils.resizeImageIfNecessary] for testability.
///
/// Reads the configurable max dimension from [CacheService] so all VLM-bound
/// images respect the user setting without each caller having to thread it.
class ImageResizer {
  const ImageResizer({CacheService? cacheService})
    : _cacheService = cacheService ?? const CacheService();

  final CacheService _cacheService;

  Future<File> resizeImageIfNecessary(File imageFile) async {
    final int maxDimension = await _cacheService.loadMaxImageDimension();
    return await ImageUtils.resizeImageIfNecessary(
      imageFile,
      maxDimension: maxDimension,
    );
  }
}
