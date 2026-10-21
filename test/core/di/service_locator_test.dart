import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';
import 'package:yofardev_captioner/core/services/cache_service.dart';
import 'package:yofardev_captioner/features/agent_api/data/services/agent_api_service.dart';
import 'package:yofardev_captioner/features/caption_search/caption_search.dart';
import 'package:yofardev_captioner/features/captioning/captioning.dart';
import 'package:yofardev_captioner/features/captioning/data/repositories/llm_caption_repository.dart';
import 'package:yofardev_captioner/features/captioning/data/services/caption_service.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/image_list.dart';
import 'package:yofardev_captioner/features/image_operations/image_operations.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';
import 'package:yofardev_captioner/features/llm_config/domain/repositories/llm_config_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/structured_captioning.dart';
import 'package:yofardev_captioner/features/tab_manager/domain/services/tab_session_registry.dart';

/// Minimal no-op file store so the registry smoke test can construct real
/// [CaptionSessionService]s without touching the filesystem.
class _FakeCaptionFileStore implements CaptionFileStore {
  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) async {
    return Right<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >((
      images: <AppImage>[],
      db: CaptionDatabase(categories: <String>[], images: <CaptionData>[]),
      dbFailure: null,
    ));
  }

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async =>
      Right<Failure, CaptionDatabase>(
        CaptionDatabase(categories: <String>[], images: <CaptionData>[]),
      );

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {}

  @override
  Future<void> removeImage(File imageFile) async {}

  @override
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  ) async {}

  @override
  Future<void> removeCaptionFiles(
    String folderPath,
    List<AppImage> images,
  ) async {}

  @override
  Future<AppImage> duplicateImage(AppImage originalImage) async =>
      originalImage;

  @override
  int compareNatural(String a, String b) => a.compareTo(b);

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) async => images;

  @override
  Future<AppImage> getSingleImageSize(AppImage image) async => image;
}

class _FakeCaptionFilterEngine implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) {
    return images;
  }
}

void main() {
  tearDown(() async {
    final GetIt container = GetIt.instance;
    await container.reset();
  });

  group('registerDependencies (DI smoke test)', () {
    test('resolves every registration and constructs every factory', () {
      final GetIt container = GetIt.instance;
      registerDependencies(container);

      // Every lazy singleton must be constructible in dependency order.
      final CacheService cacheService = container<CacheService>();
      expect(cacheService, isA<CacheService>());
      expect(container<LlmConfigService>(), isA<LlmConfigService>());
      expect(container<ILlmConfigRepository>(), isA<ILlmConfigRepository>());
      expect(container<CaptionService>(), isA<CaptionService>());
      expect(container<LlmCaptionRepository>(), isA<LlmCaptionRepository>());
      expect(container<ICaptioningRepository>(), isA<ICaptioningRepository>());
      expect(
        container<IStructuredCaptionRepository>(),
        isA<IStructuredCaptionRepository>(),
      );
      // Lazy singleton: same instance on every resolution.
      expect(
        container<IStructuredCaptionRepository>(),
        same(container<IStructuredCaptionRepository>()),
      );
      expect(container<AppFileUtils>(), isA<AppFileUtils>());
      expect(container<CaptionFileStore>(), same(container<AppFileUtils>()));
      expect(container<TabSessionRegistry>(), isA<TabSessionRegistry>());
      expect(container<AgentApiService>(), isA<AgentApiService>());
      expect(container<Logger>(), isA<Logger>());
    });

    test('param factories build fresh tab cubits per session', () {
      final GetIt container = GetIt.instance;
      registerDependencies(container);

      final CaptionSessionService sessionA = CaptionSessionService(
        fileStore: _FakeCaptionFileStore(),
        filterEngine: _FakeCaptionFilterEngine(),
      );
      final CaptionSessionService sessionB = CaptionSessionService(
        fileStore: _FakeCaptionFileStore(),
        filterEngine: _FakeCaptionFilterEngine(),
      );

      final ImageListCubit a = container<ImageListCubit>(param1: sessionA);
      final ImageListCubit b = container<ImageListCubit>(param1: sessionB);
      addTearDown(a.close);
      addTearDown(b.close);

      expect(a, isNot(same(b)));

      final CaptioningCubit captioning = container<CaptioningCubit>(
        param1: sessionA,
      );
      final StructuredCaptioningCubit structured =
          container<StructuredCaptioningCubit>(param1: sessionA);
      final ImageOperationsCubit imageOperations =
          container<ImageOperationsCubit>(param1: sessionA);
      final CaptionSearchCubit captionSearch = container<CaptionSearchCubit>(
        param1: sessionA,
      );
      final BatchJsonApplyCubit batchJsonApply = container<BatchJsonApplyCubit>(
        param1: sessionA,
      );
      addTearDown(captioning.close);
      addTearDown(structured.close);
      addTearDown(imageOperations.close);
      addTearDown(captionSearch.close);
      addTearDown(batchJsonApply.close);

      expect(captioning, isA<CaptioningCubit>());
      expect(structured, isA<StructuredCaptioningCubit>());
      expect(imageOperations, isA<ImageOperationsCubit>());
      expect(captionSearch, isA<CaptionSearchCubit>());
      expect(batchJsonApply, isA<BatchJsonApplyCubit>());
    });

    test('structured editor factory builds a cubit from its params record', () {
      final GetIt container = GetIt.instance;
      registerDependencies(container);
      SharedPreferences.setMockInitialValues(<String, Object>{});

      // Full valid shape — copied from the batch-apply fixture.
      const String json =
          '{"high_level_description":"old","style_description":{"aesthetics":"old","lighting":"old","photo":"","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"","elements":[]}}';
      final CaptionSessionService session = CaptionSessionService(
        fileStore: _FakeCaptionFileStore(),
        filterEngine: _FakeCaptionFilterEngine(),
      );

      final StructuredEditorCubit cubit = container<StructuredEditorCubit>(
        param1: (
          initialCaption: IdeogramCaption.fromJson(
            jsonDecode(json) as Map<String, dynamic>,
          ),
          imageFile: File('/tmp/x.png'),
          activeCategory: 'default',
          session: session,
          showBboxText: false,
        ),
      );
      addTearDown(cubit.close);

      expect(cubit, isA<StructuredEditorCubit>());
      expect(cubit.state.caption.highLevelDescription, 'old');
    });

    test(
      'resolves from a fresh container twice (no global state reliance)',
      () async {
        final GetIt first = GetIt.asNewInstance();
        registerDependencies(first);
        expect(first<AppFileUtils>(), isA<AppFileUtils>());
        await first.reset();

        final GetIt second = GetIt.asNewInstance();
        registerDependencies(second);
        expect(second<TabSessionRegistry>(), isA<TabSessionRegistry>());
        await second.reset();
      },
    );
  });

  group('TabSessionRegistry session lifecycle', () {
    test('create, peek, dispose cycle', () {
      final TabSessionRegistry registry = TabSessionRegistry();
      int created = 0;
      registry.sessionFactory = () {
        created += 1;
        return CaptionSessionService(
          fileStore: _FakeCaptionFileStore(),
          filterEngine: _FakeCaptionFilterEngine(),
        );
      };

      final CaptionSessionService session = registry.ensure('tab-1');
      expect(created, 1);
      // Same tab id returns the same session; a new id creates a new one.
      expect(registry.ensure('tab-1'), same(session));
      expect(registry.ensure('tab-2'), isNot(same(session)));
      expect(created, 2);
      expect(registry.peek('tab-1'), same(session));
      expect(registry.sessionFor('tab-2'), isNotNull);

      // Dispose one session; the other survives.
      registry.dispose('tab-1');
      expect(registry.peek('tab-1'), isNull);
      expect(registry.peek('tab-2'), isNotNull);

      // disposeAll clears the rest.
      registry.disposeAll();
      expect(registry.peek('tab-2'), isNull);

      // The factory survives disposeAll — sessions can be recreated.
      expect(registry.ensure('tab-3'), isNotNull);
      expect(created, 3);
    });

    test('updateTabs/tabForFolder snapshot round trip', () {
      final TabSessionRegistry registry = TabSessionRegistry();
      registry.updateTabs(<TabSessionInfo>[
        const TabSessionInfo(
          id: 'a',
          folderPath: '/tmp/a',
          displayName: 'a',
          isActive: true,
        ),
        const TabSessionInfo(
          id: 'b',
          folderPath: '/tmp/b',
          displayName: 'b',
          isActive: false,
        ),
      ]);
      expect(registry.tabs.length, 2);
      expect(registry.tabForFolder('/tmp/b')?.id, 'b');
      expect(registry.tabForFolder('/nope'), isNull);
    });

    test('ensure before binding a factory throws StateError', () {
      final TabSessionRegistry registry = TabSessionRegistry();
      expect(() => registry.ensure('tab-1'), throwsStateError);
    });
  });

  group('ImageListState (session dependency sanity)', () {
    test('default state is empty and equatable', () {
      const ImageListState state = ImageListState();
      expect(state.images, isEmpty);
      expect(const ImageListState(), equals(state));
    });
  });
}
