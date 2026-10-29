import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:nested/nested.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/export/domain/moss_bucketing.dart';
import 'package:yofardev_captioner/features/export/domain/moss_training_models.dart';
import 'package:yofardev_captioner/features/export/domain/repositories/moss_training_export_repository.dart';
import 'package:yofardev_captioner/features/export/presentation/bloc/moss_training_export_cubit.dart';
import 'package:yofardev_captioner/features/export/presentation/widgets/export_button.dart';
import 'package:yofardev_captioner/features/image_list/image_list.dart';
import 'package:yofardev_captioner/features/image_operations/image_operations.dart';

class _FakeFileStore implements CaptionFileStore {
  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) async =>
      Right<
        Failure,
        ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
      >((
        images: <AppImage>[],
        db: CaptionDatabase(
          categories: <String>['default'],
          images: <CaptionData>[],
        ),
        dbFailure: null,
      ));

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async =>
      Right<Failure, CaptionDatabase>(
        CaptionDatabase(
          categories: <String>['default'],
          images: <CaptionData>[],
        ),
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

class _StubFilterEngine implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => images;
}

class _FakeTrainingRepo implements IMossTrainingExportRepository {
  int buildCalls = 0;

  @override
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) async {
    buildCalls++;
    return Right<Failure, MossTrainingExportPlan>(
      MossTrainingExportPlan(
        options: options,
        items: <MossTrainingPrepItem>[_item()],
        skipped: const <MossTrainingSkippedImage>[],
      ),
    );
  }

  static MossTrainingExportPlan buildPlanResult() {
    return MossTrainingExportPlan(
      options: const MossTrainingExportOptions(),
      items: <MossTrainingPrepItem>[_item()],
      skipped: const <MossTrainingSkippedImage>[],
    );
  }

  static MossTrainingPrepItem _item() {
    final MossImageTransform transform = planAiToolkitTransform(
      sourceWidth: 1864,
      sourceHeight: 1864,
      resolution: 1024,
      divisibility: 16,
    );
    return MossTrainingPrepItem(
      imageId: 'a',
      fileName: 'a.png',
      sourcePath: '/fake/a.png',
      sourceWidth: 1864,
      sourceHeight: 1864,
      transform: transform,
      boxes: const <MossTrainingBox>[
        MossTrainingBox(
          label: 'object',
          caption: 'thing',
          sourceBox: <int>[0, 0, 932, 932],
          outputBox: <int>[0, 0, 512, 512],
        ),
      ],
      summaryCaption: 'a scene',
      summaryMeta: const <String>[],
      summaryPalette: const <String>[],
      sourceLength: 123,
      sourceModified: DateTime(2024),
    );
  }

  @override
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int p, int t, String f)? onProgress,
    bool Function()? isCancelled,
  }) => throw UnimplementedError();
}

const String _ideogramCaption =
    '{"high_level_description":"a scene", "style_description": '
    '{"aesthetics":"", "lighting":"", "photo":"", "medium":"photograph", '
    '"color_palette":[]}, "compositional_deconstruction": {"background":"", '
    '"elements":[]}}';

void main() {
  // Codex review findings 1 (rev 1 and rev 2): the training export flow
  // reads MossTrainingExportCubit inside the SECOND dialog, which is routed
  // ABOVE the app Navigator while the tab providers sit BELOW it
  // (MaterialApp home subtree, like tab_content). With providers only in the
  // home subtree, the inner dialog context cannot resolve the cubit unless
  // ExportButton captures and forwards it across the first showDialog.
  // This is the same scope as Codex's failing reproducer.
  testWidgets('training export resolves the tab-provided cubit from the real '
      'below-Navigator scope through both dialogs', (
    WidgetTester tester,
  ) async {
    final _FakeFileStore store = _FakeFileStore();
    final CaptionSessionService session = CaptionSessionService(
      fileStore: store,
      filterEngine: _StubFilterEngine(),
    );
    final ImageListCubit imageListCubit = ImageListCubit(session: session);
    final ImageOperationsCubit imageOperationsCubit = ImageOperationsCubit(
      session,
    );
    final _FakeTrainingRepo repo = _FakeTrainingRepo();
    final MossTrainingExportCubit trainingCubit = MossTrainingExportCubit(
      repository: repo,
    );
    addTearDown(imageOperationsCubit.close);
    addTearDown(imageListCubit.close);
    addTearDown(trainingCubit.close);
    addTearDown(session.dispose);

    final AppImage image = AppImage(
      id: 'a',
      image: File('/fake/a.png'),
      captions: const <String, CaptionEntry>{
        'default': CaptionEntry(text: _ideogramCaption),
      },
    );
    imageListCubit.emit(
      ImageListState(
        folderPath: '/folder',
        images: <AppImage>[image],
        currentImageId: 'a',
      ),
    );

    // The critical part: providers are INSIDE MaterialApp's home subtree
    // (below the Navigator), exactly like tab_content. Providers above
    // MaterialApp would leak into the dialog routes and mask the bug.
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<ImageListCubit>.value(value: imageListCubit),
            BlocProvider<ImageOperationsCubit>.value(
              value: imageOperationsCubit,
            ),
            BlocProvider<MossTrainingExportCubit>.value(value: trainingCubit),
          ],
          child: const Scaffold(body: Center(child: ExportButton())),
        ),
      ),
    );

    await tester.tap(find.text('Export as Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Select caption category to export:'), findsOneWidget);

    await tester.ensureVisible(find.text('MOSS training dataset…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MOSS training dataset…'));
    await tester.pumpAndSettle();

    // The training dialog opened through the forwarded provider — this is
    // where the unforwarded version throws ProviderNotFoundException.
    expect(find.text('Export MOSS training dataset'), findsOneWidget);
    expect(find.text('Build plan'), findsOneWidget);

    await tester.ensureVisible(find.text('Build plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build plan'));
    await tester.pumpAndSettle();

    // The plan reached the SAME tab-provided cubit and renders inside the
    // dialog: per-image row, bucket chip, and export action.
    expect(repo.buildCalls, 1);
    expect(find.textContaining('a.png'), findsOneWidget);
    expect(find.text('1024x1024 ×1'), findsOneWidget);
    expect(find.textContaining('Export dataset'), findsOneWidget);
  });

  // Codex rev-3 finding 1: staleness must be checked against LIVE session
  // state immediately before export. A caption edited in the session after
  // the preview was built must cause ZERO repository export calls (and no
  // platform save) until a fresh preview is built.
  testWidgets('session caption edit after preview blocks export with zero '
      'repository export calls', (WidgetTester tester) async {
    final _FakeFileStore store = _FakeFileStore();
    final CaptionSessionService session = CaptionSessionService(
      fileStore: store,
      filterEngine: _StubFilterEngine(),
    );
    final ImageListCubit imageListCubit = ImageListCubit(session: session);
    final ImageOperationsCubit imageOperationsCubit = ImageOperationsCubit(
      session,
    );
    final _CountingExportRepo repo = _CountingExportRepo();
    final MossTrainingExportCubit trainingCubit = MossTrainingExportCubit(
      repository: repo,
    );
    addTearDown(imageOperationsCubit.close);
    addTearDown(imageListCubit.close);
    addTearDown(trainingCubit.close);
    addTearDown(session.dispose);

    final AppImage image = AppImage(
      id: 'a',
      image: File('/fake/a.png'),
      captions: const <String, CaptionEntry>{
        'default': CaptionEntry(text: _ideogramCaption),
      },
    );
    imageListCubit.emit(
      ImageListState(
        folderPath: '/folder',
        images: <AppImage>[image],
        currentImageId: 'a',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<ImageListCubit>.value(value: imageListCubit),
            BlocProvider<ImageOperationsCubit>.value(
              value: imageOperationsCubit,
            ),
            BlocProvider<MossTrainingExportCubit>.value(value: trainingCubit),
          ],
          child: const Scaffold(body: Center(child: ExportButton())),
        ),
      ),
    );

    await tester.tap(find.text('Export as Archive'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('MOSS training dataset…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MOSS training dataset…'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Build plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build plan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Export dataset'), findsOneWidget);

    // Edit the caption in the LIVE session after the preview was built.
    final AppImage edited = AppImage(
      id: 'a',
      image: File('/fake/a.png'),
      captions: const <String, CaptionEntry>{
        'default': CaptionEntry(text: 'edited after audit'),
      },
    );
    imageListCubit.emit(
      ImageListState(
        folderPath: '/folder',
        images: <AppImage>[edited],
        currentImageId: 'a',
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Export dataset'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Export dataset'));
    await tester.pumpAndSettle();

    // The stale preview refused to run: no export, no save, with a
    // visible rebuild message.
    expect(repo.exportCalls, 0);
    expect(find.textContaining('stale'), findsOneWidget);
  });
}

/// Records export calls; buildPlan returns a single-item plan.
class _CountingExportRepo implements IMossTrainingExportRepository {
  int exportCalls = 0;

  @override
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) async {
    return Right<Failure, MossTrainingExportPlan>(
      _FakeTrainingRepo.buildPlanResult(),
    );
  }

  @override
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int p, int t, String f)? onProgress,
    bool Function()? isCancelled,
  }) async {
    exportCalls++;
    return Right<Failure, (MossTrainingExportResult, Uint8List)>((
      const MossTrainingExportResult(
        imageCount: 1,
        captionCount: 1,
        droppedBoxCount: 0,
        warnings: <String>[],
        outputHashes: <String, String>{},
      ),
      Uint8List.fromList(<int>[1]),
    ));
  }
}
