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
}
