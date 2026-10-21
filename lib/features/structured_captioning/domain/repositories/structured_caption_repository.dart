import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/structured_batch_overrides.dart';
import '../../../../core/utils/cancel_token.dart';
import '../models/structured_mode.dart';

/// Port for the structured captioning pipeline. Implemented by the data
/// layer's `StructuredCaptionRepository`.
abstract class IStructuredCaptionRepository {
  Future<Either<Failure, IdeogramCaption>> generateStructuredCaption(
    LlmConfig config,
    File imageFile, {
    required void Function(String step) onProgress,
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

  Future<Map<int, List<int>>> computeSamBboxes({
    required File imageFile,
    required IdeogramCaption caption,
  });
}
