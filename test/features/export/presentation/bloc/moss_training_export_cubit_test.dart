import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/export/domain/moss_bucketing.dart';
import 'package:yofardev_captioner/features/export/domain/moss_training_models.dart';
import 'package:yofardev_captioner/features/export/domain/repositories/moss_training_export_repository.dart';
import 'package:yofardev_captioner/features/export/presentation/bloc/moss_training_export_cubit.dart';

/// Repository whose futures complete only when the test releases them —
/// deterministic await-boundary tests (Codex rev-2 finding 5).
class _DeferredRepo implements IMossTrainingExportRepository {
  final Completer<Either<Failure, MossTrainingExportPlan>> planCompleter =
      Completer<Either<Failure, MossTrainingExportPlan>>();

  @override
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) => planCompleter.future;

  @override
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int p, int t, String f)? onProgress,
    bool Function()? isCancelled,
  }) async => Right<Failure, (MossTrainingExportResult, Uint8List)>((
    const MossTrainingExportResult(
      imageCount: 0,
      captionCount: 0,
      droppedBoxCount: 0,
      warnings: <String>[],
      outputHashes: <String, String>{},
    ),
    Uint8List.fromList(<int>[1]),
  ));
}

class _StubRepo implements IMossTrainingExportRepository {
  _StubRepo({this.failExport = false}) : cancelAfter = 0;

  final int cancelAfter;
  final bool failExport;
  int exportCalls = 0;
  List<int>? recordedProgress;

  static MossTrainingExportPlan plan({int itemCount = 2}) {
    final List<MossTrainingPrepItem> items = <MossTrainingPrepItem>[];
    for (int i = 0; i < itemCount; i++) {
      items.add(_item('img$i.png'));
    }
    return MossTrainingExportPlan(
      options: const MossTrainingExportOptions(),
      items: items,
      skipped: const <MossTrainingSkippedImage>[],
    );
  }

  static MossTrainingPrepItem _item(String name) {
    return MossTrainingPrepItem(
      imageId: name,
      fileName: name,
      sourcePath: '/fake/$name',
      sourceWidth: 1864,
      sourceHeight: 1864,
      transform: planAiToolkitTransform(
        sourceWidth: 1864,
        sourceHeight: 1864,
        resolution: 1024,
        divisibility: 16,
      ),
      boxes: const <MossTrainingBox>[],
      summaryCaption: 'scene',
      summaryMeta: const <String>[],
      summaryPalette: const <String>[],
      sourceLength: 1,
      sourceModified: DateTime(2024),
    );
  }

  @override
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) async {
    return Right<Failure, MossTrainingExportPlan>(plan());
  }

  @override
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int p, int t, String f)? onProgress,
    bool Function()? isCancelled,
  }) async {
    exportCalls++;
    for (int i = 0; i < plan.items.length; i++) {
      if (isCancelled != null && isCancelled()) {
        return const Left<Failure, (MossTrainingExportResult, Uint8List)>(
          FailureUnexpected(message: 'export cancelled'),
        );
      }
      onProgress?.call(i, plan.items.length, plan.items[i].fileName);
    }
    if (failExport) {
      return const Left<Failure, (MossTrainingExportResult, Uint8List)>(
        FailureUnexpected(message: 'boom'),
      );
    }
    return Right<Failure, (MossTrainingExportResult, Uint8List)>((
      const MossTrainingExportResult(
        imageCount: 2,
        captionCount: 2,
        droppedBoxCount: 0,
        warnings: <String>[],
        outputHashes: <String, String>{},
      ),
      Uint8List.fromList(<int>[1, 2, 3]),
    ));
  }
}

void main() {
  // Codex review finding 9: export lifecycle — progress emissions,
  // cancellation, stale-plan detection, save-failure reporting.
  group('MossTrainingExportCubit', () {
    test('plan build emits planning then planned', () async {
      final _StubRepo repo = _StubRepo();
      final MossTrainingExportCubit cubit = MossTrainingExportCubit(
        repository: repo,
      );
      addTearDown(cubit.close);
      await cubit.buildPlan(
        images: const <AppImage>[],
        category: 'default',
        options: const MossTrainingExportOptions(),
      );
      expect(cubit.state, isA<MossTrainingExportPlanned>());
    });

    test('reset drops a stale plan', () async {
      final _StubRepo repo = _StubRepo();
      final MossTrainingExportCubit cubit = MossTrainingExportCubit(
        repository: repo,
      );
      addTearDown(cubit.close);
      await cubit.buildPlan(
        images: const <AppImage>[],
        category: 'default',
        options: const MossTrainingExportOptions(),
      );
      cubit.reset();
      expect(cubit.state, isA<MossTrainingExportInitial>());
      expect(
        cubit.isPlanStale(images: const <AppImage>[], category: 'default'),
        isTrue,
      );
    });

    test('isPlanStale detects a changed source set', () async {
      final _StubRepo repo = _StubRepo();
      final MossTrainingExportCubit cubit = MossTrainingExportCubit(
        repository: repo,
      );
      addTearDown(cubit.close);
      final List<AppImage> images = <AppImage>[
        AppImage(
          id: 'a',
          image: File('/fake/a.png'),
          captions: const <String, CaptionEntry>{},
        ),
      ];
      // Build directly against isPlanStale without a full buildPlan (the
      // cubit records what it planned).
      await cubit.buildPlan(
        images: images,
        category: 'default',
        options: const MossTrainingExportOptions(),
      );
      expect(cubit.isPlanStale(images: images, category: 'default'), isFalse);
      expect(
        cubit.isPlanStale(images: <AppImage>[], category: 'default'),
        isTrue,
      );
      expect(cubit.isPlanStale(images: images, category: 'other'), isTrue);
    });

    test('cancel before exportPlan skips the save step entirely', () async {
      final _StubRepo repo = _StubRepo();
      final MossTrainingExportCubit cubit = MossTrainingExportCubit(
        repository: repo,
      );
      addTearDown(cubit.close);
      await cubit.buildPlan(
        images: const <AppImage>[],
        category: 'default',
        options: const MossTrainingExportOptions(),
      );
      cubit.cancel();
      await cubit.exportPlan();
      final MossTrainingExportState state = cubit.state;
      expect(state, isA<MossTrainingExportDone>());
      expect((state as MossTrainingExportDone).cancelled, isTrue);
      expect(state.saved, isFalse);
      // The repository reported the cancellation via isCancelled.
      expect(repo.exportCalls, 1);
    });

    test(
      'cancel during planning discards the plan when it completes',
      () async {
        final _DeferredRepo repo = _DeferredRepo();
        final MossTrainingExportCubit cubit = MossTrainingExportCubit(
          repository: repo,
        );
        addTearDown(cubit.close);
        final Future<void> building = cubit.buildPlan(
          images: const <AppImage>[],
          category: 'default',
          options: const MossTrainingExportOptions(),
        );
        // Cancel while the (deferred) plan build is in flight.
        cubit.cancel();
        repo.planCompleter.complete(
          Right<Failure, MossTrainingExportPlan>(_StubRepo.plan(itemCount: 1)),
        );
        await building;
        await Future<void>.delayed(Duration.zero);
        // The completed plan must NOT be published.
        expect(cubit.state, isA<MossTrainingExportDone>());
        expect((cubit.state as MossTrainingExportDone).cancelled, isTrue);
      },
    );

    test(
      'reset while planning cancels the pending plan (reopen is clean)',
      () async {
        final _DeferredRepo repo = _DeferredRepo();
        final MossTrainingExportCubit cubit = MossTrainingExportCubit(
          repository: repo,
        );
        addTearDown(cubit.close);
        final Future<void> building = cubit.buildPlan(
          images: const <AppImage>[],
          category: 'default',
          options: const MossTrainingExportOptions(),
        );
        // "Reopen": reset while the plan is still building.
        cubit.reset();
        repo.planCompleter.complete(
          Right<Failure, MossTrainingExportPlan>(_StubRepo.plan(itemCount: 1)),
        );
        await building;
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state, isNot(isA<MossTrainingExportPlanned>()));
        // A subsequent buildPlan starts from a clean state.
        expect(
          cubit.isPlanStale(images: const <AppImage>[], category: 'x'),
          isTrue,
        );
      },
    );

    test(
      'isPlanStale detects live CAPTION text changes (not just ids/paths)',
      () async {
        final _StubRepo repo = _StubRepo();
        final MossTrainingExportCubit cubit = MossTrainingExportCubit(
          repository: repo,
        );
        addTearDown(cubit.close);
        final AppImage image = AppImage(
          id: 'a',
          image: File('/fake/a.png'),
          captions: const <String, CaptionEntry>{
            'default': CaptionEntry(text: 'audited text'),
          },
        );
        await cubit.buildPlan(
          images: <AppImage>[image],
          category: 'default',
          options: const MossTrainingExportOptions(),
        );
        // Same id/path, but the caption text changed in the live session.
        final AppImage edited = AppImage(
          id: 'a',
          image: File('/fake/a.png'),
          captions: const <String, CaptionEntry>{
            'default': CaptionEntry(text: 'edited after audit'),
          },
        );
        expect(
          cubit.isPlanStale(images: <AppImage>[edited], category: 'default'),
          isTrue,
        );
        // Unchanged text stays fresh.
        expect(
          cubit.isPlanStale(images: <AppImage>[image], category: 'default'),
          isFalse,
        );
      },
    );

    test('repository failure surfaces as an error state', () async {
      final _StubRepo repo = _StubRepo(failExport: true);
      final MossTrainingExportCubit cubit = MossTrainingExportCubit(
        repository: repo,
      );
      addTearDown(cubit.close);
      await cubit.buildPlan(
        images: const <AppImage>[],
        category: 'default',
        options: const MossTrainingExportOptions(),
      );
      await cubit.exportPlan();
      expect(cubit.state, isA<MossTrainingExportError>());
      expect(
        (cubit.state as MossTrainingExportError).message,
        contains('boom'),
      );
    });
  });
}
