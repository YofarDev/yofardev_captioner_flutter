import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/features/captioning/data/models/caption_database.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';

void main() {
  group('AppFileUtils Migration', () {
    late Directory tempDir;
    late AppFileUtils fileUtils;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('migration_test');
      fileUtils = AppFileUtils();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('migrates v1 database to v3 format', () async {
      // Create old format db.json with proper JSON encoding
      final Map<String, dynamic> oldDb = <String, dynamic>{
        'images': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'test-id-1',
            'filename': 'test.jpg',
            'captionModel': 'gpt-4',
            'captionTimestamp': '2025-01-15T10:30:00Z',
            'lastModified': '2025-01-15T10:30:00Z',
          },
        ],
      };

      final File dbFile = File(p.join(tempDir.path, 'db.json'));
      // Use jsonEncode to properly format JSON
      await dbFile.writeAsString(jsonEncode(oldDb));

      // Create corresponding .txt file
      final File txtFile = File(p.join(tempDir.path, 'test.txt'));
      await txtFile.writeAsString('Test caption');

      // Verify files were created
      expect(await dbFile.exists(), isTrue);
      expect(await txtFile.exists(), isTrue);

      // Read and migrate
      final CaptionDatabase db = await fileUtils.readDb(tempDir.path);

      // Verify migration
      expect(db.version, equals(3));
      expect(db.categories, equals(<String>['default']));
      expect(db.activeCategory, equals('default'));
      expect(db.images.length, equals(1));
      expect(db.images.first.captions.containsKey('default'), isTrue);
      expect(db.images.first.captions['default']?.text, equals('Test caption'));
    });

    test('creates new v3 database for empty folder', () async {
      final CaptionDatabase db = await fileUtils.readDb(tempDir.path);

      expect(db.version, equals(3));
      expect(db.categories, equals(<String>['default']));
      expect(db.activeCategory, equals('default'));
      expect(db.images.length, equals(0));
    });

    test(
      'backfills captions from legacy txt files into existing v2 database',
      () async {
        final Map<String, dynamic> v2Db = <String, dynamic>{
          'version': 2,
          'categories': <String>['default'],
          'activeCategory': 'default',
          'images': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'img-1',
              'filename': '01.jpg',
              'captions': <String, dynamic>{},
              'lastModified': null,
            },
          ],
        };

        await File(
          p.join(tempDir.path, 'db.json'),
        ).writeAsString(jsonEncode(v2Db));
        await File(p.join(tempDir.path, '01.jpg')).writeAsBytes(<int>[1, 2, 3]);
        await File(
          p.join(tempDir.path, '01.txt'),
        ).writeAsString('Legacy caption');

        final List<AppImage> images = await fileUtils.onFolderPicked(
          tempDir.path,
        );
        final CaptionDatabase updatedDb = await fileUtils.readDb(tempDir.path);

        expect(images, hasLength(1));
        expect(
          images.first.captions['default']?.text,
          equals('Legacy caption'),
        );
        expect(
          updatedDb.images.first.captions['default']?.text,
          equals('Legacy caption'),
        );
      },
    );

    test(
      'imports legacy txt captions when opening a folder without db.json',
      () async {
        await File(p.join(tempDir.path, '01.jpg')).writeAsBytes(<int>[1, 2, 3]);
        await File(
          p.join(tempDir.path, '01.txt'),
        ).writeAsString('Imported caption');

        final List<AppImage> images = await fileUtils.onFolderPicked(
          tempDir.path,
        );
        final CaptionDatabase updatedDb = await fileUtils.readDb(tempDir.path);

        expect(images, hasLength(1));
        expect(
          images.first.captions['default']?.text,
          equals('Imported caption'),
        );
        expect(updatedDb.images, hasLength(1));
        expect(
          updatedDb.images.first.captions['default']?.text,
          equals('Imported caption'),
        );
      },
    );
  });
}
