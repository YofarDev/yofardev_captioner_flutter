import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yofardev_captioner/features/captioning/data/models/caption_database.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cubit_tags_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('_saveDb persists tags onto CaptionData in db.json', () async {
    File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');

    final ImageListCubit cubit = ImageListCubit();
    await cubit.onFolderPicked(tempDir.path);

    // updateImage matches by id, so reuse the loaded image's id to ensure the
    // update actually applies and _saveDb runs with the tagged image.
    final AppImage image = cubit.state.images.first
        .copyWith(tags: const <String>['sunset', 'landscape']);
    await cubit.updateImage(image: image);

    final File dbFile = File(p.join(tempDir.path, 'db.json'));
    final Map<String, dynamic> json =
        jsonDecode(dbFile.readAsStringSync()) as Map<String, dynamic>;
    final CaptionDatabase db = CaptionDatabase.fromJson(json);

    expect(db.images, hasLength(1));
    expect(db.images.first.tags, <String>['sunset', 'landscape']);
  });

  group('ImageListCubit tag operations', () {
    late Directory tempDir;
    late ImageListCubit cubit;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('cubit_tags_ops_');
      File(p.join(tempDir.path, 'a.jpg')).writeAsStringSync('');
      // Seed a db.json so onFolderPicked loads one image.
      File(p.join(tempDir.path, 'db.json')).writeAsStringSync(jsonEncode({
        'version': 3,
        'categories': <String>['default'],
        'activeCategory': 'default',
        'images': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'img-1',
            'filename': 'a.jpg',
            'captions': <String, dynamic>{},
            'tags': <String>[],
          },
        ],
      }));
      cubit = ImageListCubit();
      await cubit.onFolderPicked(tempDir.path);
      // Select the image.
      cubit.onImageSelected('img-1');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    AppImage currentImage(ImageListCubit c) =>
        c.state.images.firstWhere((AppImage i) => i.id == 'img-1');

    test('addTag appends a new tag and persists', () async {
      await cubit.addTag('sunset');
      expect(currentImage(cubit).tags, <String>['sunset']);
      // Verify persisted to disk.
      final Map<String, dynamic> json = jsonDecode(
        File(p.join(tempDir.path, 'db.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      final List<dynamic> tags =
          (json['images'] as List).first['tags'] as List<dynamic>;
      expect(tags, <String>['sunset']);
    });

    test('addTag dedupes and trims', () async {
      await cubit.addTag('sunset');
      await cubit.addTag('  sunset  ');
      expect(currentImage(cubit).tags, <String>['sunset']);
    });

    test('addTag ignores empty/whitespace input', () async {
      await cubit.addTag('   ');
      expect(currentImage(cubit).tags, <String>[]);
    });

    test('removeTag removes an existing tag', () async {
      await cubit.addTag('sunset');
      await cubit.addTag('landscape');
      await cubit.removeTag('sunset');
      expect(currentImage(cubit).tags, <String>['landscape']);
    });

    test('setTags replaces the whole list (normalized + deduped)', () async {
      await cubit.addTag('old');
      await cubit.setTags(<String>['  sunset  ', 'night', 'sunset']);
      expect(currentImage(cubit).tags, <String>['sunset', 'night']);
    });

    test('operations are no-op when no image selected', () async {
      cubit.emit(cubit.state.copyWith(
        currentImageId: null,
        images: <AppImage>[],
      ));
      await cubit.addTag('x');
      expect(cubit.state.images, isEmpty);
    });
  });
}
