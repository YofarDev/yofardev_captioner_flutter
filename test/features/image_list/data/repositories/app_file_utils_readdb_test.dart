import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final GetIt locator = GetIt.instance;
  if (!locator.isRegistered<Logger>()) {
    locator.registerLazySingleton<Logger>(() => Logger('Test'));
  }

  late Directory tempDir;
  final AppFileUtils fileUtils = AppFileUtils();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('read_db_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File dbFile() => File('${tempDir.path}/db.json');

  group('readDb failure semantics', () {
    test(
      'absent db.json is an empty default database (not a failure)',
      () async {
        final Either<Failure, CaptionDatabase> result = await fileUtils.readDb(
          tempDir.path,
        );

        expect(result.isRight(), isTrue);
        final CaptionDatabase db = result.getRight().toNullable()!;
        expect(db.categories, <String>['default']);
        expect(db.images, isEmpty);
      },
    );

    test(
      'corrupt db.json maps to Failure.invalidData instead of an empty db',
      () async {
        await dbFile().writeAsString('{not valid json');

        final Either<Failure, CaptionDatabase> result = await fileUtils.readDb(
          tempDir.path,
        );

        final Failure? failure = result.getLeft().toNullable();
        expect(failure, isA<FailureInvalidData>());
      },
    );

    test('valid db.json parses to the stored database', () async {
      await dbFile().writeAsString(
        jsonEncode(<String, dynamic>{
          'version': 4,
          'categories': <String>['default', 'art'],
          'activeCategory': 'art',
          'images': <Map<String, dynamic>>[],
          'categoryFormats': <String, String>{},
        }),
      );

      final Either<Failure, CaptionDatabase> result = await fileUtils.readDb(
        tempDir.path,
      );

      final CaptionDatabase db = result.getRight().toNullable()!;
      expect(db.categories, <String>['default', 'art']);
      expect(db.activeCategory, 'art');
    });

    test(
      'structurally wrong db.json (valid JSON, wrong shape) maps to invalidData',
      () async {
        await dbFile().writeAsString(jsonEncode(<String>['a', 'b']));

        final Either<Failure, CaptionDatabase> result = await fileUtils.readDb(
          tempDir.path,
        );

        expect(result.getLeft().toNullable(), isA<FailureInvalidData>());
      },
    );
  });
}
