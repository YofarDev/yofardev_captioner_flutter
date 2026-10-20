import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/utils/cancel_token.dart';
import '../../domain/repositories/captioning_repository.dart';
import 'caption_repository.dart';

class CaptioningRepository implements ICaptioningRepository {
  final CaptionRepository _captionRepository;
  CaptioningRepository({CaptionRepository? captionRepository})
    : _captionRepository = captionRepository ?? CaptionRepository();

  @override
  Future<Either<Failure, AppImage>> captionImage(
    LlmConfig config,
    AppImage image,
    String prompt, {
    String category = 'default',
    CancelToken? cancelToken,
  }) async {
    final Either<Failure, String> captionResult = await _captionRepository
        .getCaption(config, image, prompt, cancelToken: cancelToken);
    // Never bang-unwrap a Left: an LLM/auth/network failure must propagate
    // as Left(Failure) so per-image error handling in the cubit can kick in.
    return captionResult.fold<Either<Failure, AppImage>>(
      Left<Failure, AppImage>.new,
      (String caption) =>
          _buildCaptionedImage(config, image, category, caption),
    );
  }

  Right<Failure, AppImage> _buildCaptionedImage(
    LlmConfig config,
    AppImage image,
    String category,
    String caption,
  ) {
    final DateTime timestamp = DateTime.now();
    return Right<Failure, AppImage>(
      image.copyWith(
        captions: <String, CaptionEntry>{
          ...image.captions,
          category: CaptionEntry(
            text: caption,
            model: config.name,
            timestamp: timestamp,
          ),
        },
        lastModified: timestamp,
      ),
    );
  }

  /// Rewrites the existing caption for the given category (text-only). The
  /// resulting caption is marked as edited so it is skipped by future "All
  /// images" vision batches, matching how manual edits are treated.
  @override
  Future<Either<Failure, AppImage>> rewriteCaption(
    LlmConfig config,
    AppImage image,
    String instructions, {
    String category = 'default',
    CancelToken? cancelToken,
  }) async {
    final String currentCaption = image.captions[category]?.text ?? '';
    final Either<Failure, String> rewriteResult = await _captionRepository
        .rewriteCaption(config, currentCaption, instructions);
    // Never bang-unwrap a Left (see captionImage).
    final String? rewrittenOrFailure = rewriteResult.getRight().toNullable();
    if (rewrittenOrFailure == null) {
      return Left<Failure, AppImage>(rewriteResult.getLeft().toNullable()!);
    }
    final String rewritten = rewrittenOrFailure;
    final Failure? jsonFailure = _validateRewrittenJson(
      currentCaption,
      rewritten,
    );
    if (jsonFailure != null) {
      return Left<Failure, AppImage>(jsonFailure);
    }
    final DateTime timestamp = DateTime.now();
    return Right<Failure, AppImage>(
      image.copyWith(
        captions: <String, CaptionEntry>{
          ...image.captions,
          category: CaptionEntry(
            text: rewritten,
            model: config.name,
            timestamp: timestamp,
            isEdited: true,
          ),
        },
        lastModified: timestamp,
      ),
    );
  }

  /// If the original caption was JSON, validates the rewritten result is also
  /// valid JSON so the JSON structure is not corrupted.
  /// Returns a Failure when [rewritten] breaks the JSON structure of
  /// [original]; null otherwise.
  Failure? _validateRewrittenJson(String original, String rewritten) {
    if (!original.trim().startsWith('{')) {
      return null;
    }
    try {
      jsonDecode(rewritten);
      return null;
    } catch (e) {
      return const Failure.invalidData(
        message:
            'The rewritten caption is no longer valid JSON. '
            'The original caption appears to be structured JSON but the '
            'rewrite returned plain text. Try different rewrite instructions '
            'or rephrase them to preserve the JSON structure.',
      );
    }
  }

  /// Reads the caption from [sourceCategory], transforms it text-only via the
  /// LLM using [userPrompt], and writes the result into [targetCategory]. No
  /// image is sent. The target caption is marked edited so future vision "All"
  /// batches skip it. Caller must ensure the source caption is non-empty.
  @override
  Future<Either<Failure, AppImage>> transformCaption(
    LlmConfig config,
    AppImage image,
    String sourceCategory,
    String targetCategory,
    String userPrompt,
  ) async {
    final String sourceText = image.captions[sourceCategory]?.text ?? '';
    final Either<Failure, String> transformResult = await _captionRepository
        .transformCaption(config, sourceText, userPrompt);
    // Never bang-unwrap a Left (see captionImage).
    final String? transformedOrNull = transformResult.getRight().toNullable();
    if (transformedOrNull == null) {
      return Left<Failure, AppImage>(transformResult.getLeft().toNullable()!);
    }
    final String transformed = transformedOrNull;
    final DateTime timestamp = DateTime.now();
    return Right<Failure, AppImage>(
      image.copyWith(
        captions: <String, CaptionEntry>{
          ...image.captions,
          targetCategory: CaptionEntry(
            text: transformed,
            model: config.name,
            timestamp: timestamp,
            isEdited: true,
          ),
        },
        lastModified: timestamp,
      ),
    );
  }
}
