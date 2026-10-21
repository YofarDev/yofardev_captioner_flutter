import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/caption_session/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/caption_session/domain/services/filter_parser_engine.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';

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

  group('save guard while db.json is unreadable', () {
    test(
      'updateImage after a corrupt-db load leaves db.json bytes UNCHANGED',
      () async {
        await File('${tempDir.path}/a.jpg').writeAsBytes(<int>[1, 2, 3]);
        const String corruptBytes = '{corrupt not json';
        final File dbFile = File('${tempDir.path}/db.json');
        await dbFile.writeAsString(corruptBytes);

        final CaptionSessionService session = buildSession();
        addTearDown(session.dispose);
        await session.onFolderPicked(tempDir.path, force: true);
        expect(session.state.dbLoadError, isNotNull);

        // In-memory edit goes through the normal save path.
        await session.updateImage(
          image: session.state.images.single.copyWith(
            captions: <String, CaptionEntry>{
              'default': const CaptionEntry(text: 'edited while corrupt'),
            },
          ),
        );

        // The corrupt db.json on disk must not be clobbered by an
        // empty-caption database written from memory.
        expect(await dbFile.readAsString(), corruptBytes);
        // The edit itself stays in memory.
        expect(
          session.state.images.single.captions['default']?.text,
          'edited while corrupt',
        );
      },
    );

    test('saving works again once a healthy folder is loaded', () async {
      await File('${tempDir.path}/a.jpg').writeAsBytes(<int>[1, 2, 3]);

      final CaptionSessionService session = buildSession();
      addTearDown(session.dispose);
      await session.onFolderPicked(tempDir.path, force: true);
      expect(session.state.dbLoadError, isNull);

      await session.updateImage(
        image: session.state.images.single.copyWith(
          captions: <String, CaptionEntry>{
            'default': const CaptionEntry(text: 'hello'),
          },
        ),
      );

      expect(
        await File('${tempDir.path}/db.json').readAsString(),
        contains('hello'),
      );
    });
  });
}
