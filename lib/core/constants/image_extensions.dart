import 'package:path/path.dart' as p;

/// File extensions the app treats as captionable images, lowercase with the
/// leading dot. Keep in sync with folder scanning and the Agent API.
const Set<String> kSupportedImageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
};

/// True when [path]'s extension is one of [kSupportedImageExtensions].
bool isSupportedImageFile(String path) {
  final String extension = p.extension(path).toLowerCase();
  return kSupportedImageExtensions.contains(extension);
}
