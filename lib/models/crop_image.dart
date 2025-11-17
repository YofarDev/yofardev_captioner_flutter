import 'dart:typed_data';

class CropImage {
  Uint8List? bytes;
  double targetAspectRatio;

  CropImage({required this.bytes, required this.targetAspectRatio});
}
