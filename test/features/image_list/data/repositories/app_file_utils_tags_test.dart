import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tags_migration_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  void writeDb(String folderPath, Map<String, dynamic> json) {
    File(p.join(folderPath, 'db.json')).writeAsStringSync(jsonEncode(json));
  }

  test('v2 db without tags field migrates and hydrates empty tags', () async {
    writeDb(tempDir.path, <String, dynamic>{
      'version': 2,
      'categories': <String>['default'],
      'activeCategory': 'default',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'img-1',
          'filename': 'a.jpg',
          'captions': <String, dynamic>{},
        },
      ],
    });
    File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');

    final AppFileUtils utils = AppFileUtils();
    final List<AppImage> images = await utils.onFolderPicked(tempDir.path);

    expect(images, hasLength(1));
    expect(images.single.tags, <String>[]);
  });

  test('v2 db with existing tags preserves them through migration', () async {
    writeDb(tempDir.path, <String, dynamic>{
      'version': 2,
      'categories': <String>['default'],
      'activeCategory': 'default',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'img-1',
          'filename': 'a.jpg',
          'captions': <String, dynamic>{},
          'tags': <String>['sunset', 'wide'],
        },
      ],
    });
    File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');

    final AppFileUtils utils = AppFileUtils();
    final List<AppImage> images = await utils.onFolderPicked(tempDir.path);

    expect(images.single.tags, <String>['sunset', 'wide']);
  });

  test('migrated db is re-stamped to version 3 on disk', () async {
    writeDb(tempDir.path, <String, dynamic>{
      'version': 2,
      'categories': <String>['default'],
      'activeCategory': 'default',
      'images': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'img-1',
          'filename': 'a.jpg',
          'captions': <String, dynamic>{},
        },
      ],
    });
    File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');

    final AppFileUtils utils = AppFileUtils();
    await utils.onFolderPicked(tempDir.path);

    final Map<String, dynamic> written =
        jsonDecode(File(p.join(tempDir.path, 'db.json')).readAsStringSync())
            as Map<String, dynamic>;
    expect(written['version'], 3);
  });
}
