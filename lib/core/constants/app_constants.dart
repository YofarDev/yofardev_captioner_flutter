class AppConstants {
  /// Decode width for image-list thumbnails (80 logical px at up to 2x DPR).
  ///
  /// Decoding at full resolution made scrolling a folder of large images
  /// hold every thumbnail's full decoded bitmap in the image cache.
  static const int imageListThumbDecodeWidth = 160;

  /// Decode width for the blurred backdrop behind the current image.
  /// The backdrop is blurred and darkened, so detail beyond this is invisible.
  static const int currentImageBackdropDecodeWidth = 256;

  static List<String> aspectRatioStrings = <String>[
    "16:9",
    "9:16",
    "5:4",
    "4:5",
    "4:3",
    "3:4",
    "3:2",
    "2:3",
    "1:1",
  ];
}
