import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/archive_exporter.dart';

void main() {
  group('ArchiveExporter.archiveFileName', () {
    test('default category has no suffix', () {
      expect(
        ArchiveExporter.archiveFileName('/photos/cats', 'default'),
        'cats.zip',
      );
    });

    test('named category is appended', () {
      expect(
        ArchiveExporter.archiveFileName('/photos/cats', 'tags'),
        'cats-tags.zip',
      );
    });
  });
}
