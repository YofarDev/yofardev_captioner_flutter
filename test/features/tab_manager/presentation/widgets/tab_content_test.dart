import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/image_list/image_list.dart';
import 'package:yofardev_captioner/features/tab_manager/presentation/bloc/tab_manager_cubit.dart';
import 'package:yofardev_captioner/features/tab_manager/presentation/widgets/tab_content.dart';

/// Minimal no-op file store so the [TabManagerCubit]-created sessions never
/// touch the filesystem (copied from test/core/di/service_locator_test.dart).
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // TabManagerCubit sets the window title on every state change.
  const MethodChannel windowManagerChannel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        windowManagerChannel,
        (MethodCall methodCall) async => null,
      );

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('renders the workspace slot and provides the session cubits', (
    WidgetTester tester,
  ) async {
    registerDependencies(GetIt.instance);
    final TabManagerCubit tabManager = TabManagerCubit(
      fileUtils: _FakeCaptionFileStore(),
    );
    addTearDown(tabManager.close);

    await tester.pumpWidget(
      BlocProvider<TabManagerCubit>.value(
        value: tabManager,
        child: const MaterialApp(
          home: Scaffold(
            body: TabContent(tabId: 'default', child: Text('workspace-slot')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('workspace-slot'), findsOneWidget);
    // The session cubits are provided above the slot.
    expect(find.byType(BlocProvider<ImageListCubit>), findsOneWidget);
  });
}
