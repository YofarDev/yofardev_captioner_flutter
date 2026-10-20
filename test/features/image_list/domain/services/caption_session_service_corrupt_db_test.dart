import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/filter_parser_engine.dart';

/// Real-store end-to-end proof of the corrupt-db UX (plan 4.4): a corrupt
/// db.json must NOT yield an empty library — images still load (captions
/// empty) and the session surfaces dbLoadError for the warning banner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final GetIt locator = GetIt.instance;
  if (!locator.isRegistered<Logger>()) {
    locator.registerLazySingleton<Logger>(() => Logger('Test'));
  }

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('corrupt_db_session');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  CaptionSessionService buildSession() => CaptionSessionService(
    fileStore: AppFileUtils(),
    filterEngine: const FilterParserCaptionEngine(),
  );

  group('CaptionSessionService with a real file store', () {
    test(
      'corrupt db.json loads images with empty captions and sets dbLoadError',
      () async {
        await File('${tempDir.path}/a.jpg').writeAsBytes(<int>[1, 2, 3]);
        await File('${tempDir.path}/db.json').writeAsString('{corrupt');

        final CaptionSessionService session = buildSession();
        addTearDown(session.dispose);

        await session.onFolderPicked(tempDir.path, force: true);

        expect(session.state.images, hasLength(1));
        expect(session.state.images.single.captions, isEmpty);
        expect(session.state.dbLoadError, isNotNull);
      },
    );

    test('absent db.json loads an empty database without any error', () async {
      await File('${tempDir.path}/a.jpg').writeAsBytes(<int>[1, 2, 3]);

      final CaptionSessionService session = buildSession();
      addTearDown(session.dispose);

      await session.onFolderPicked(tempDir.path, force: true);

      expect(session.state.images, hasLength(1));
      expect(session.state.dbLoadError, isNull);
    });
  });
}
