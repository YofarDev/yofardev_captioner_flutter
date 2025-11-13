import '../models/app_image.dart';

extension SizeAspectRatio on AppImage {
  String get aspectRatio {
    if (width == 0 || height == 0) {
      return '0:0';
    }
    final int gcdValue = _gcd(width, height);
    return '${width ~/ gcdValue}:${height ~/ gcdValue}';
  }

  int _gcd(int a, int b) {
    int x = a;
    int y = b;
    while (y != 0) {
      final int temp = y;
      y = x % y;
      x = temp;
    }
    return x;
  }
}

extension FileSizeFormat on int {
  String get readableFileSize {
    const List<String> suffixes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double size = toDouble();
    int i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
