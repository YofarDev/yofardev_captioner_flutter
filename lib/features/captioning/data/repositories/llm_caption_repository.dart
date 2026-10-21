import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/utils/cancel_token.dart';
import '../services/caption_service.dart';

/// LLM-backed caption operations (low-level: one call, one caption string).
/// Never throws across the boundary (except
/// [CancellationException], which is control flow, not failure).
class LlmCaptionRepository {
  final CaptionService _captionService;
  LlmCaptionRepository({CaptionService? captionService})
    : _captionService = captionService ?? CaptionService();

  Future<Either<Failure, String>> getCaption(
    LlmConfig config,
    AppImage image,
    String prompt, {
    CancelToken? cancelToken,
  }) async {
    try {
      return Right<Failure, String>(
        await _captionService.getCaption(
          config,
          image.image,
          prompt,
          cancelToken: cancelToken,
        ),
      );
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, String>(
        _mapLlmError(e, stackTrace: st, tag: 'LlmCaptionRepository.getCaption'),
      );
    }
  }

  /// Rewrites an existing caption (text-only) using the LLM.
  Future<Either<Failure, String>> rewriteCaption(
    LlmConfig config,
    String currentCaption,
    String instructions, {
    CancelToken? cancelToken,
  }) async {
    try {
      return Right<Failure, String>(
        await _captionService.rewriteCaption(
          config,
          currentCaption,
          instructions,
          cancelToken: cancelToken,
        ),
      );
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, String>(
        _mapLlmError(
          e,
          stackTrace: st,
          tag: 'LlmCaptionRepository.rewriteCaption',
        ),
      );
    }
  }

  /// Generic text-only transform driven entirely by [userPrompt]
  /// (e.g. JSON → natural language).
  Future<Either<Failure, String>> transformCaption(
    LlmConfig config,
    String sourceText,
    String userPrompt, {
    CancelToken? cancelToken,
  }) async {
    try {
      return Right<Failure, String>(
        await _captionService.transformCaption(
          config,
          sourceText,
          userPrompt,
          cancelToken: cancelToken,
        ),
      );
    } on CancellationException {
      rethrow;
    } catch (e, st) {
      return Left<Failure, String>(
        _mapLlmError(
          e,
          stackTrace: st,
          tag: 'LlmCaptionRepository.transformCaption',
        ),
      );
    }
  }

  /// Known-exception classification: [ApiException] maps to
  /// unauthorized (401/403) or serverError; [TimeoutException] and other
  /// transport errors map to network; everything else falls back to
  /// [mapExceptionToFailure].
  Failure _mapLlmError(
    Object e, {
    required StackTrace stackTrace,
    required String tag,
  }) {
    if (e is ApiException) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return Failure.unauthorized(message: e.message);
      }
      if (e.message.contains('401') || e.message.contains('403')) {
        return Failure.unauthorized(message: e.message);
      }
      return Failure.serverError(message: e.message);
    }
    return mapExceptionToFailure(e, stackTrace: stackTrace, tag: tag);
  }
}
