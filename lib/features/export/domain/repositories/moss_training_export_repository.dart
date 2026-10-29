import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../moss_training_models.dart';

/// Domain boundary for the MOSS training dataset export: builds a
/// reviewable preparation plan, then produces the ZIP archive
/// (`images/<name>.<ext>` + one native `.json` caption per image, manifest
/// at the archive root) after full validation.
abstract class IMossTrainingExportRepository {
  /// Resolves captions ([Ideogram] or MOSS drafts) against exact decoded
  /// dimensions and computes the trainer-identical transforms. Pure with
  /// respect to disk — nothing is written.
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  });

  /// Executes [plan]: decodes/transforms/encodes each image off the UI
  /// isolate, stages everything in a unique temp directory, validates
  /// (every image has a caption; dimensions match the plan), and returns
  /// the ZIP bytes plus a summary. Staging is cleaned up on failure.
  ///
  /// [onProgress] fires per image; [isCancelled] is polled between images —
  /// a cancelled run returns a Failure and never reaches the save step.
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int processed, int total, String fileName)? onProgress,
    bool Function()? isCancelled,
  });
}
