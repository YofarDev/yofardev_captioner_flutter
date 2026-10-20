import 'dart:typed_data';
import 'dart:ui';

class CropImage {
  Uint8List? bytes;
  Size targetAspectRatio;

  CropImage({required this.bytes, required this.targetAspectRatio});
}
