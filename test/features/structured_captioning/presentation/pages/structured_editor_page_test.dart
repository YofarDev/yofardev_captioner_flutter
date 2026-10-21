import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:image/image.dart' as img;
import 'package:nested/nested.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/image_list/image_list.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';
import 'package:yofardev_captioner/features/llm_config/llm_config.dart';
import 'package:yofardev_captioner/features/structured_captioning/structured_captioning.dart';

const String kValidIdeogramJson =
    '{"high_level_description":"old","style_description":{"aesthetics":"old","lighting":"old","photo":"","medium":"photograph","color_palette":[]},"compositional_deconstruction":{"background":"","elements":[]}}';

/// Minimal no-op file store so the session never touches the filesystem
/// (copied from test/core/di/service_locator_test.dart).
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

Future<File> writeTempPng(WidgetTester tester) async {
  // Real filesystem IO must run outside the test's FakeAsync zone or the
  // await never completes.
  final File? png = await tester.runAsync(() async {
    final Directory dir = await Directory.systemTemp.createTemp('editor_page');
    addTearDown(() {
      dir.deleteSync(recursive: true);
    });
    final File file = File('${dir.path}/img.png');
    await file.writeAsBytes(img.encodePng(img.Image(width: 4, height: 4)));
    return file;
  });
  if (png == null) {
    throw StateError('failed to create temp png');
  }
  return png;
}

void main() {
  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('renders the editor for a structured caption', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    registerDependencies(GetIt.instance);
    final File png = await writeTempPng(tester);
    final CaptionSessionService session = CaptionSessionService(
      fileStore: _FakeCaptionFileStore(),
      filterEngine: _FakeCaptionFilterEngine(),
    );
    final ImageListCubit imageListCubit = ImageListCubit(session: session);
    addTearDown(imageListCubit.close);
    final LlmConfigsCubit llmConfigsCubit = LlmConfigsCubit(
      llmConfigService: LlmConfigService(),
    );
    addTearDown(llmConfigsCubit.close);

    // The editor layout targets a desktop window; the default 800x600 test
    // surface overflows its toolbars.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<ImageListCubit>.value(value: imageListCubit),
          BlocProvider<LlmConfigsCubit>.value(value: llmConfigsCubit),
        ],
        child: MaterialApp(
          home: StructuredEditorPage(
            imageFile: png,
            captionJson: kValidIdeogramJson,
            activeCategory: 'default',
            imageListCubit: imageListCubit,
          ),
        ),
      ),
    );
    await tester.pump(); // let the cubit factory and _loadTitles() land
    await tester.pump();

    // The cubit factory resolved through DI; the editor shows the seeded
    // high-level description.
    expect(find.byType(StructuredEditorPage), findsOneWidget);
    expect(find.text('old'), findsWidgets);
  });
}
