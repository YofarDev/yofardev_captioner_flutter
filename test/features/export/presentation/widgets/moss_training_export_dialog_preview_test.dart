import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:nested/nested.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/export/domain/moss_bucketing.dart';
import 'package:yofardev_captioner/features/export/domain/moss_training_models.dart';
import 'package:yofardev_captioner/features/export/domain/repositories/moss_training_export_repository.dart';
import 'package:yofardev_captioner/features/export/presentation/bloc/moss_training_export_cubit.dart';
import 'package:yofardev_captioner/features/export/presentation/widgets/moss_training_export_dialog.dart';
import 'package:yofardev_captioner/features/image_list/image_list.dart';

/// Caller-level preview fixtures (Codex rev-4 finding): pane-only tests
/// cannot catch wrong caller inputs, so these pump the REAL
/// [MossTrainingExportDialog] plan view and assert the PREPARED pane's
/// image widget reflects the realized RESIZED frame (scaleTo), not the
/// original source frame.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dialog_preview_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  File writePng(String name, int width, int height) {
    final img.Image image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(7, 7, 7));
    final File f = File('${tempDir.path}/$name')
      ..writeAsBytesSync(img.encodePng(image));
    return f;
  }

  MossTrainingPrepItem prepItem({
    required String fileName,
    required String path,
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final MossImageTransform transform = planAiToolkitTransform(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      resolution: 1024,
      divisibility: 16,
    );
    return MossTrainingPrepItem(
      imageId: fileName,
      fileName: fileName,
      sourcePath: path,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      transform: transform,
      boxes: <MossTrainingBox>[
        // Full prepared frame — the box representing the ENTIRE resized
        // image must align with the drawn image.
        MossTrainingBox(
          label: 'object',
          caption: 'whole frame',
          sourceBox: <int>[0, 0, sourceWidth, sourceHeight],
          outputBox: <int>[0, 0, transform.bucketWidth, transform.bucketHeight],
        ),
      ],
      summaryCaption: 'scene',
      summaryMeta: const <String>[],
      summaryPalette: const <String>[],
      sourceLength: 1,
      sourceModified: DateTime(2024),
    );
  }

  Future<void> pumpPlannedDialog(
    WidgetTester tester, {
    required MossTrainingExportPlan plan,
    required File imageFile,
  }) async {
    final MossTrainingExportCubit cubit = MossTrainingExportCubit(
      repository: _FixedPlanRepo(plan),
    );
    addTearDown(cubit.close);
    final ImageListCubit imageListCubit = _stubSession(imageFile);
    addTearDown(imageListCubit.close);
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<MossTrainingExportCubit>.value(value: cubit),
          ],
          child: MossTrainingExportDialog(
            images: imageListCubit.state.images,
            category: 'default',
            imageListCubit: imageListCubit,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Build the plan through the cubit (after the dialog's post-frame
    // reset) so plannedCaptions are recorded and the plan view renders.
    await cubit.buildPlan(
      images: imageListCubit.state.images,
      category: 'default',
      options: const MossTrainingExportOptions(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('1864→1024 downscale: prepared image widget fills the whole view '
      '(not the upper-left source region)', (WidgetTester tester) async {
    final File file = writePng('a.png', 1864, 1864);
    final MossTrainingPrepItem item = prepItem(
      fileName: 'a.png',
      path: file.path,
      sourceWidth: 1864,
      sourceHeight: 1864,
    );
    final MossTrainingExportPlan plan = MossTrainingExportPlan(
      options: const MossTrainingExportOptions(),
      items: <MossTrainingPrepItem>[item],
      skipped: const <MossTrainingSkippedImage>[],
    );
    await pumpPlannedDialog(tester, plan: plan, imageFile: file);

    // Expand the row so the panes exist.
    await tester.tap(find.textContaining('a.png'));
    await tester.pumpAndSettle();

    // Two panes: source (first) and prepared (second).
    final List<File> paneImages = tester
        .widgetList<Image>(find.byType(Image))
        .map((Image w) => (w.image as FileImage).file)
        .toList();
    expect(paneImages.length, 2);
    expect(paneImages.every((File f) => f.path == file.path), isTrue);

    // Prepared pane geometry: image drawn size must match the VIEWPORT
    // (bucket 1024×1024) — the realized resize makes the resized image
    // exactly fill the view. With the caller bug (sourceWidth passed),
    // the drawn image would be 1864/1024 ≈ 1.82× the viewport.
    final Size preparedImageSize = tester.getSize(find.byType(Image).last);
    final MossImageTransform t = item.transform;
    expect(t.bucketWidth, 1024);
    expect(t.bucketHeight, 1024);
    // The prepared image spans the same width as its viewport (both are
    // the 1024 frame at the pane's contain scale) — within a couple of
    // device pixels.
    expect(
      preparedImageSize.width,
      closeTo(1024 * (preparedImageSize.width / t.scaleToWidth), 2.5),
    );
    final double scale = preparedImageSize.width / t.scaleToWidth;
    expect(preparedImageSize.height, closeTo(t.scaleToHeight * scale, 2.5));
    // Decisive ratio check: image size vs viewport (view = bucket).
    final Rect viewport = tester.getRect(
      find
          .ancestor(
            of: find.byType(Image).last,
            matching: find.byType(ClipRect),
          )
          .first,
    );
    expect(
      viewport.width,
      closeTo(preparedImageSize.width, 2.5),
      reason:
          'resized image must fill the prepared view exactly — '
          'passing sourceWidth would render ~1.82× the viewport',
    );
    expect(viewport.height, closeTo(preparedImageSize.height, 2.5));
  });

  testWidgets(
    'non-square resized+cropped: prepared image reflects the scaleTo frame '
    '(wider than the bucket view by the cropped margins)',
    (WidgetTester tester) async {
      // 1000×2000 → bucket 720×1456, scaleTo 728×1456, crop (4, 0).
      final File file = writePng('tall.png', 1000, 2000);
      final MossTrainingPrepItem item = prepItem(
        fileName: 'tall.png',
        path: file.path,
        sourceWidth: 1000,
        sourceHeight: 2000,
      );
      final MossImageTransform t = item.transform;
      expect(t.bucketWidth, 720);
      expect(t.bucketHeight, 1456);
      expect(t.scaleToWidth, 728);
      expect(t.scaleToHeight, 1456);
      expect(t.cropX, 4);
      final MossTrainingExportPlan plan = MossTrainingExportPlan(
        options: const MossTrainingExportOptions(),
        items: <MossTrainingPrepItem>[item],
        skipped: const <MossTrainingSkippedImage>[],
      );
      await pumpPlannedDialog(tester, plan: plan, imageFile: file);

      await tester.tap(find.textContaining('tall.png'));
      await tester.pumpAndSettle();

      final Size preparedImageSize = tester.getSize(find.byType(Image).last);
      final double scale = preparedImageSize.width / t.scaleToWidth;
      // The drawn image is the scaleTo frame; it is wider than the bucket
      // view by exactly 2×cropX (the cropped margins are clipped).
      expect(preparedImageSize.width, closeTo(t.scaleToWidth * scale, 2.5));
      expect(preparedImageSize.height, closeTo(t.scaleToHeight * scale, 2.5));
      final Rect viewport = tester.getRect(
        find
            .ancestor(
              of: find.byType(Image).last,
              matching: find.byType(ClipRect),
            )
            .first,
      );
      expect(viewport.width, closeTo(t.bucketWidth * scale, 2.5));
      expect(viewport.height, closeTo(t.bucketHeight * scale, 2.5));
      // Decisive: image wider than viewport by the crop margins — the
      // buggy caller (source frame 1000 wide) would overshoot by
      // 1000−720 instead of 728−720.
      expect(
        preparedImageSize.width - viewport.width,
        closeTo((t.scaleToWidth - t.bucketWidth) * scale, 2.5),
      );
    },
  );
}

ImageListCubit _stubSession(File imageFile) {
  final CaptionSessionService session = CaptionSessionService(
    fileStore: _NoopStore(),
    filterEngine: _Passthrough(),
  );
  final ImageListCubit cubit = ImageListCubit(session: session);
  cubit.emit(
    ImageListState(
      folderPath: '/f',
      images: <AppImage>[
        // imageFile is runtime data — this literal cannot be const.
        // ignore: prefer_const_literals_to_create_immutables
        AppImage(id: 'a', image: imageFile, captions: <String, CaptionEntry>{}),
      ],
      currentImageId: 'a',
    ),
  );
  return cubit;
}

/// Returns the fixture plan; records nothing else.
class _FixedPlanRepo implements IMossTrainingExportRepository {
  _FixedPlanRepo(this.plan);

  final MossTrainingExportPlan plan;

  @override
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) async => Right<Failure, MossTrainingExportPlan>(plan);

  @override
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int p, int t, String f)? onProgress,
    bool Function()? isCancelled,
  }) => throw UnimplementedError();
}

class _NoopStore implements CaptionFileStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Passthrough implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => images;
}
