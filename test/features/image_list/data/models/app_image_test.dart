import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';

void main() {
  group('AppImage tags', () {
    test('defaults to empty list', () {
      final AppImage image = AppImage(
        id: 'x',
        image: File('a.jpg'),
        captions: const <String, CaptionEntry>{},
      );
      expect(image.tags, <String>[]);
    });

    test('copyWith preserves tags when omitted', () {
      final AppImage image = AppImage(
        id: 'x',
        image: File('a.jpg'),
        captions: const <String, CaptionEntry>{},
        tags: const <String>['sunset'],
      );
      final AppImage copy = image.copyWith(id: 'y');
      expect(copy.tags, <String>['sunset']);
    });

    test('copyWith replaces tags when provided', () {
      final AppImage image = AppImage(
        id: 'x',
        image: File('a.jpg'),
        captions: const <String, CaptionEntry>{},
        tags: const <String>['sunset'],
      );
      final AppImage copy = image.copyWith(tags: const <String>['night']);
      expect(copy.tags, <String>['night']);
    });
  });
}
