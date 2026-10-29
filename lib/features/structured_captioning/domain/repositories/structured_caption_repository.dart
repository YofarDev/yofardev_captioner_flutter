import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/structured_batch_overrides.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../../core/utils/cancel_token.dart';
import '../models/structured_mode.dart';

/// Port for the structured captioning pipeline. Implemented by the data
/// layer's `StructuredCaptionRepository`.
abstract class IStructuredCaptionRepository {
  /// Runs the full pipeline and returns the caption in [format]'s JSON
  /// structure (Ideogram or MOSS layout).
  Future<Either<Failure, StructuredCaptionDocument>> generateStructuredCaption(
    LlmConfig config,
    File imageFile, {
    required void Function(String step) onProgress,
    CaptionFormat format = CaptionFormat.ideogram,
    StructuredBatchOverrides? overrides,
    bool debugMode = false,
    bool disableSam = false,
    bool vlmEmitsXyxy = true,
    String guidance = '',
    StructuredMode mode = StructuredMode.singleShot,
    CancelToken? cancelToken,
  });

  Future<Either<Failure, IdeogramElement>> recaptionElement({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
    required int elementIndex,
    String? instructions,
    bool cropToBbox = false,
  });

  Future<Either<Failure, IdeogramStyleDescription>> recaptionStyle({
    required LlmConfig config,
    required File imageFile,
    required IdeogramCaption currentCaption,
  });

  /// Computes SAM bounding boxes for the caption's elements.
  ///
  /// Errors surface as `Left(Failure)`. The SAM subprocess's own soft-fails
  /// (logged in `sam_process_service`) still come back as `Right({})`.
  Future<Either<Failure, Map<int, List<int>>>> computeSamBboxes({
    required File imageFile,
    required IdeogramCaption caption,
  });
}
