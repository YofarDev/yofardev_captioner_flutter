import 'package:flutter/painting.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_image.dart';

/// Evicts all cached decodings of [images] (full-resolution and the
/// downscaled variants used by the list thumbs and the blurred backdrop).
/// Prevents stale images when files are added, renamed, or replaced.
///
/// Lives outside the domain session service because it touches Flutter's
/// global ImageCache; both the `ImageListCubit` adapter and the
/// `TabManagerCubit` session factory call it before folder reloads.
void evictImageCache(Iterable<AppImage> images) {
  final ImageCache cache = PaintingBinding.instance.imageCache;
  for (final AppImage image in images) {
    final FileImage provider = FileImage(image.image);
    cache.evict(provider);
    cache.evict(
      ResizeImage(provider, width: AppConstants.imageListThumbDecodeWidth),
    );
    cache.evict(
      ResizeImage(
        provider,
        width: AppConstants.currentImageBackdropDecodeWidth,
      ),
    );
  }
}
