import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/utils/cancel_token.dart';
import 'package:yofardev_captioner/features/caption_search/presentation/bloc/caption_search_cubit.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/captioning/captioning.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/presentation/bloc/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/bloc/image_operations_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';
import 'package:yofardev_captioner/features/llm_config/presentation/bloc/llm_configs_cubit.dart';
import 'package:yofardev_captioner/features/main_area/presentation/pages/main_area_view.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/bloc/structured_captioning_cubit.dart';
import 'package:yofardev_captioner/features/tab_manager/presentation/bloc/tab_manager_cubit.dart';

/// 1x1 transparent PNG so [CurrentImageView]'s `Image.file` has a decodable
/// file (a missing file would surface an image-provider error in the test).
final Uint8List _kPngBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

/// No-op file store so the session never touches the real database.
class _NoopFileStore implements CaptionFileStore {
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

class _PassthroughFilter implements CaptionFilterEngine {
  const _PassthroughFilter();

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

/// [ICaptioningRepository] stub — the flows under test never generate.
class _StubCaptioningRepository implements ICaptioningRepository {
  @override
  Future<Either<Failure, AppImage>> captionImage(
    LlmConfig config,
    AppImage image,
    String prompt, {
    String category = 'default',
    CancelToken? cancelToken,
  }) async {
    return Right<Failure, AppImage>(image);
  }

  @override
  Future<Either<Failure, AppImage>> rewriteCaption(
    LlmConfig config,
    AppImage image,
    String instructions, {
    String category = 'default',
    CancelToken? cancelToken,
  }) async {
    return Right<Failure, AppImage>(image);
  }

  @override
  Future<Either<Failure, AppImage>> transformCaption(
    LlmConfig config,
    AppImage image,
    String sourceCategory,
    String targetCategory,
    String userPrompt, {
    CancelToken? cancelToken,
  }) async {
    return Right<Failure, AppImage>(image);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // StructuredCaptionRepository pulls its Logger from the locator.
  locator.registerLazySingleton<Logger>(() => Logger('TestMainArea'));

  // Mock window_manager channel (TabManagerCubit calls windowManager.setTitle).
  const MethodChannel windowManagerChannel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        windowManagerChannel,
        (MethodCall methodCall) async => null,
      );

  group('MainAreaView empty state (home page open-folder flow)', () {
    late ImageListCubit imageListCubit;

    tearDown(() => imageListCubit.close());

    testWidgets('shows the empty-state hero and pick-folder entry', (
      WidgetTester tester,
    ) async {
      imageListCubit = ImageListCubit();

      await tester.pumpWidget(
        BlocProvider<ImageListCubit>.value(
          value: imageListCubit,
          child: const MaterialApp(home: Scaffold(body: MainAreaView())),
        ),
      );
      await tester.pump();

      expect(find.text('Yofardev Captioner'), findsOneWidget);
      expect(
        find.text('Drop a folder of images anywhere to start captioning'),
        findsOneWidget,
      );
      expect(find.text('Pick folder'), findsOneWidget);
    });

    testWidgets('offers to reopen the last folder and routes it through the '
        'tab manager', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'folderPath': '/tmp/captioner_photos',
      });
      imageListCubit = ImageListCubit();
      final TabManagerCubit tabManager = TabManagerCubit(
        fileUtils: AppFileUtils(),
      );
      addTearDown(tabManager.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ImageListCubit>.value(value: imageListCubit),
            BlocProvider<TabManagerCubit>.value(value: tabManager),
          ],
          child: const MaterialApp(home: Scaffold(body: MainAreaView())),
        ),
      );
      // Let the async CacheService.loadFolderPath future land.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final Finder reopen = find.text('Reopen captioner_photos');
      expect(reopen, findsOneWidget);

      await tester.tap(reopen);
      // onInit waits ~150ms before loading; flush the timer.
      await tester.pump(const Duration(milliseconds: 400));

      expect(tabManager.state.activeTab.folderPath, '/tmp/captioner_photos');
      expect(imageListCubit.state.folderPath, '/tmp/captioner_photos');
    });
  });

  group('MainAreaView editor shell (caption → save flow)', () {
    late Directory tempDir;
    late CaptionSessionService session;
    late ImageListCubit imageListCubit;
    late TabManagerCubit tabManager;
    late LlmConfigsCubit llmConfigsCubit;
    late CaptioningCubit captioningCubit;
    late StructuredCaptioningCubit structuredCubit;
    late CaptionSearchCubit searchCubit;
    late ImageOperationsCubit operationsCubit;
    late ImageListState seedState;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('captioner_ma_test');
      final File imageFile = File('${tempDir.path}/one.png')
        ..writeAsBytesSync(_kPngBytes);
      seedState = ImageListState(
        images: <AppImage>[
          AppImage(
            id: 'one',
            image: imageFile,
            captions: const <String, CaptionEntry>{},
            size: _kPngBytes.length,
          ),
        ],
        folderPath: tempDir.path,
        currentImageId: 'one',
      );
      session = CaptionSessionService(
        fileStore: _NoopFileStore(),
        filterEngine: const _PassthroughFilter(),
      );
    });

    tearDown(() async {
      imageListCubit.close();
      tabManager.close();
      llmConfigsCubit.close();
      captioningCubit.close();
      structuredCubit.close();
      searchCubit.close();
      operationsCubit.close();
      await tempDir.delete(recursive: true);
    });

    Future<void> pumpShell(WidgetTester tester) async {
      // Desktop-sized surface: the editor shell's fixed-height rows overflow
      // the default 800x600 test surface.
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      imageListCubit = ImageListCubit(session: session);
      // The cubit adopts its initial const state into the session on
      // construction — seed AFTER so the session keeps the image.
      imageListCubit.emit(seedState);
      tabManager = TabManagerCubit(fileUtils: AppFileUtils());
      llmConfigsCubit = LlmConfigsCubit(llmConfigService: LlmConfigService());
      captioningCubit = CaptioningCubit(
        session,
        captioningRepository: _StubCaptioningRepository(),
      );
      structuredCubit = StructuredCaptioningCubit(
        session,
        repository: StructuredCaptionRepository(),
      );
      searchCubit = CaptionSearchCubit(session: session);
      operationsCubit = ImageOperationsCubit(session);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ImageListCubit>.value(value: imageListCubit),
            BlocProvider<TabManagerCubit>.value(value: tabManager),
            BlocProvider<LlmConfigsCubit>.value(value: llmConfigsCubit),
            BlocProvider<CaptioningCubit>.value(value: captioningCubit),
            BlocProvider<StructuredCaptioningCubit>.value(
              value: structuredCubit,
            ),
            BlocProvider<CaptionSearchCubit>.value(value: searchCubit),
            BlocProvider<ImageOperationsCubit>.value(value: operationsCubit),
          ],
          child: const MaterialApp(home: Scaffold(body: MainAreaView())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('typing a caption persists it into the session', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester);

      final Finder captionField = find.descendant(
        of: find.byType(CaptionTextArea),
        matching: find.byType(TextField),
      );
      expect(captionField, findsOneWidget);

      await tester.enterText(captionField, 'a test caption');
      // Caption edits are debounced at 300ms; flush the timer.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        session.state.images.first.captions['default']?.text,
        'a test caption',
      );
      expect(
        imageListCubit.state.images.first.captions['default']?.text,
        'a test caption',
      );
    });
  });
}
