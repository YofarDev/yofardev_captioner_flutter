import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../../core/config/service_locator.dart';
import '../../../../core/utils/cancel_token.dart';
import '../../../llm_config/data/models/llm_config.dart';
import '../../../llm_config/data/models/llm_provider_type.dart';
import '../models/caption/caption_request.dart';
import '../models/caption/caption_response.dart';
import '../models/caption/content.dart';
import '../models/caption/message.dart';
import 'image_resizer.dart';
import 'process_runner.dart';

class CaptionService {
  final Logger _logger = locator<Logger>();
  final ProcessRunner _processRunner;
  final http.Client _httpClient;
  final ImageResizer _imageResizer;

  CaptionService({
    ProcessRunner? processRunner,
    http.Client? httpClient,
    ImageResizer? imageResizer,
  }) : _processRunner = processRunner ?? const ProcessRunner(),
       _httpClient = httpClient ?? http.Client(),
       _imageResizer = imageResizer ?? const ImageResizer();

  Future<String> getCaption(
    LlmConfig config,
    File image,
    String prompt, {
    int? maxTokens,
    CancelToken? cancelToken,
  }) {
    if (config.providerType == LlmProviderType.localMlx) {
      return _getLocalCaption(
        config,
        image,
        prompt,
        maxTokens: maxTokens,
        cancelToken: cancelToken,
      );
    } else {
      return _getRemoteCaption(
        config,
        image,
        prompt,
        maxTokens: maxTokens,
        cancelToken: cancelToken,
      );
    }
  }

  /// Rewrites an existing caption text-only (no image is sent). The model
  /// returns the full rewritten caption.
  ///
  /// Only remote (API) providers are supported: local MLX (`mlx_vlm`) is
  /// vision-only and cannot do text completion. Single-image use case only;
  /// batch rewrite is a possible future extension.
  Future<String> rewriteCaption(
    LlmConfig config,
    String currentCaption,
    String instructions,
  ) {
    if (config.providerType == LlmProviderType.localMlx) {
      throw ApiException(
        'Caption rewrite requires a remote (API) provider; local MLX is vision-only.',
      );
    }
    return _getRemoteRewrite(config, currentCaption, instructions);
  }

  /// Asks the model to repair malformed JSON emitted by another (vision) model
  /// — a second-chance pass used by the structured-captioning pipeline when the
  /// VLM response fails to parse. Text-only (no image). Returns the repaired
  /// raw text; the caller parses it.
  ///
  /// Local MLX is vision-only and unsupported (throws), mirroring
  /// [rewriteCaption]. The caller is expected to catch and fall back to the
  /// original parse error when this is unavailable.
  Future<String> repairJson(
    LlmConfig config,
    String brokenOutput, {
    int? maxTokens,
  }) {
    if (config.providerType == LlmProviderType.localMlx) {
      throw ApiException(
        'JSON repair requires a remote (API) provider; local MLX is vision-only.',
      );
    }
    return _getRemoteRepair(config, brokenOutput, maxTokens: maxTokens);
  }

  Future<String> _getLocalCaption(
    LlmConfig config,
    File image,
    String prompt, {
    int? maxTokens,
    CancelToken? cancelToken,
  }) async {
    File? imageToSend;
    try {
      imageToSend = await _imageResizer.resizeImageIfNecessary(image);

      // Default to 8192 (enough for the structured deconstruction JSON of
      // complex scenes like crowds) when the caller doesn't override — the
      // model default is often too small.
      final int effectiveMaxTokens = maxTokens ?? 8192;
      final List<String> arguments = <String>[
        '--model',
        config.model,
        '--temperature',
        '0.0',
        '--max-tokens',
        effectiveMaxTokens.toString(),
        '--prompt',
        prompt,
        '--image',
        imageToSend.path,
      ];

      final String executable = (config.mlxPath?.isNotEmpty ?? false)
          ? config.mlxPath!
          : 'mlx_vlm.generate';
      final ProcessResult result = await _processRunner.run(
        executable,
        arguments,
        cancelToken: cancelToken,
      );

      if (result.exitCode == 0) {
        final String output = result.stdout.toString();
        _logger.info('MLX output: $output');
        final RegExp regex = RegExp(
          r'<\|im_start\|>assistant\n\n(.*?)\n==========',
          dotAll: true,
        );
        final Match? match = regex.firstMatch(output);

        if (match != null && match.groupCount >= 1) {
          return match
              .group(1)!
              .replaceAll(RegExp('<thought>.*?</thought>', dotAll: true), '')
              .trim();
        } else {
          _logger.severe('Could not parse caption from MLX output: $output');
          throw ApiException('Failed to parse caption from MLX output.');
        }
      } else {
        _logger.severe('Error getting local caption: ${result.stderr}');
        throw ApiException(
          'Failed to generate caption with local model (exit code ${result.exitCode}): ${result.stderr}',
        );
      }
    } on ProcessException catch (e) {
      _logger.severe('ProcessException while getting local caption: $e');
      throw ApiException(
        'Failed to run local captioning script. Is Python with mlx_vlm installed and in your PATH? Details: $e',
      );
    } finally {
      if (imageToSend != null && imageToSend.path != image.path) {
        try {
          await imageToSend.delete();
        } catch (e) {
          _logger.warning('Failed to delete temporary file: $e');
        }
      }
    }
  }

  Future<String> _getRemoteCaption(
    LlmConfig config,
    File image,
    String prompt, {
    int? maxTokens,
    CancelToken? cancelToken,
  }) async {
    File? imageToSend;
    try {
      if (config.url == null || config.apiKey == null) {
        throw ApiException(
          'URL and API Key are required for remote providers.',
        );
      }
      imageToSend = await _imageResizer.resizeImageIfNecessary(image);
      final Uint8List bytes = await imageToSend.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final String url = buildUrl(config.url!);

      final CaptionRequest request = CaptionRequest(
        model: config.model,
        maxTokens: maxTokens,
        messages: <Message>[
          Message(
            role: 'user',
            content: <Content>[
              Content(type: 'text', text: prompt),
              Content(
                type: 'image_url',
                imageUrl: ImageUrl(url: 'data:image/jpeg;base64,$base64Image'),
              ),
            ],
          ),
        ],
      );

      final http.Response response = await _postOrCancel(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        return _parseChatResponse(response);
      } else {
        _logger.severe('Error response: ${response.body}');
        throw ApiException(
          'Failed to load caption (${response.statusCode}): ${response.body}',
        );
      }
    } finally {
      if (imageToSend != null && imageToSend.path != image.path) {
        imageToSend.delete();
      }
    }
  }

  Future<String> _getRemoteRewrite(
    LlmConfig config,
    String currentCaption,
    String instructions,
  ) async {
    if (config.url == null || config.apiKey == null) {
      throw ApiException('URL and API Key are required for remote providers.');
    }

    final bool isJson = _looksLikeJson(currentCaption);

    final String systemPrompt;
    if (isJson) {
      systemPrompt =
          'You are a caption rewriting assistant. The caption you receive is '
          'in JSON format with a specific schema. Rewrite the caption '
          'according to the user instructions while preserving the exact '
          'JSON structure and all original fields. Only modify the text '
          'values inside the JSON — never change keys, remove fields, or '
          'alter the schema. Output ONLY the full rewritten JSON caption — '
          'no explanations, no preface, no markdown formatting.';
    } else {
      systemPrompt =
          'You are a caption rewriting assistant. Rewrite the given caption '
          'according to the user instructions. Output ONLY the full rewritten '
          'caption — no explanations, no preface, no quotes. Preserve the '
          'language, tone and formatting style of the original unless the '
          'instructions say otherwise.';
    }

    final String userPrompt =
        '$instructions\n\n'
        'Caption to rewrite:\n$currentCaption';

    final CaptionRequest request = CaptionRequest(
      model: config.model,
      messages: <Message>[
        Message(
          role: 'system',
          content: <Content>[Content(type: 'text', text: systemPrompt)],
        ),
        Message(
          role: 'user',
          content: <Content>[Content(type: 'text', text: userPrompt)],
        ),
      ],
    );

    final String url = buildUrl(config.url!);

    final http.Response response = await _httpClient.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
        'Accept': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return _parseChatResponse(response);
    } else {
      _logger.severe('Error response: ${response.body}');
      throw ApiException(
        'Failed to rewrite caption (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<String> _getRemoteRepair(
    LlmConfig config,
    String brokenOutput, {
    int? maxTokens,
  }) async {
    if (config.url == null || config.apiKey == null) {
      throw ApiException('URL and API Key are required for remote providers.');
    }

    const String systemPrompt =
        'You repair malformed JSON emitted by another model.\n'
        'Return exactly one compact valid JSON object. No markdown. No '
        'commentary.\n'
        'Preserve the original content and field names whenever possible.\n'
        'If the response contains extra prose, remove the prose.\n'
        'If the response is truncated or impossible to fully repair, return '
        'the most complete valid object that preserves the usable content.';

    // Cap the broken payload so a runaway VLM output can't blow the context
    // window — keep the head and tail where the structural damage usually is.
    final String trimmed = _capForRepair(brokenOutput);
    final String userPrompt =
        'The model response below was supposed to be a structured '
        'image-caption JSON object.\n\n'
        'Repair the response into one valid JSON object.\n\n'
        'Model response:\n$trimmed';

    final CaptionRequest request = CaptionRequest(
      model: config.model,
      maxTokens: maxTokens,
      messages: <Message>[
        Message(
          role: 'system',
          content: <Content>[Content(type: 'text', text: systemPrompt)],
        ),
        Message(
          role: 'user',
          content: <Content>[Content(type: 'text', text: userPrompt)],
        ),
      ],
    );

    final String url = buildUrl(config.url!);

    final http.Response response = await _httpClient.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
        'Accept': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return _parseChatResponse(response);
    } else {
      _logger.severe('Error response: ${response.body}');
      throw ApiException(
        'Failed to repair JSON (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Trims a broken model output to at most [limit] chars, keeping head + tail
  /// (where JSON structural damage tends to sit) and dropping the middle.
  String _capForRepair(String output, {int limit = 24000}) {
    final String trimmed = output.trim();
    if (trimmed.length <= limit) return trimmed;
    final int half = limit ~/ 2;
    return '${trimmed.substring(0, half).trim()}\n\n'
        '... [middle omitted for JSON repair] ...\n\n'
        '${trimmed.substring(trimmed.length - half).trim()}';
  }

  /// Parses a chat completions 200 response into the assistant message text.
  ///
  /// Throws [ApiException] when the response is malformed OR when the model
  /// was cut off by the `max_tokens` limit (`finish_reason: "length"`). The
  /// latter is critical for structured-JSON generation, where a truncated
  /// response produces invalid JSON (`FormatException: unexpected end of
  /// input`) downstream. Detecting it here lets callers surface an
  /// actionable message instead.
  String _parseChatResponse(http.Response response) {
    try {
      final CaptionResponse captionResponse = CaptionResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (captionResponse.choices.isNotEmpty) {
        final Choice choice = captionResponse.choices.first;
        if (choice.finishReason == 'length') {
          _logger.severe(
            'Response truncated by max_tokens (finish_reason=length). '
            'Content length: ${choice.message.content.length} chars.',
          );
          throw ApiException(
            'The model hit the max_tokens limit and the response was '
            'truncated. This usually happens with complex images that '
            'produce long output. The partial response cannot be used. '
            'Try again, increase max_tokens, or use a model with a larger '
            'output capacity.',
          );
        }
        return choice.message.content
            .replaceAll(RegExp('<thought>.*?</thought>', dotAll: true), '')
            .trim();
      } else {
        throw ApiException('Invalid response format: ${response.body}');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      _logger.severe('Error decoding response: $e');
      throw ApiException('Failed to decode response: $e');
    }
  }

  /// Checks whether [text] looks like a JSON object (starts with `{`).
  bool _looksLikeJson(String text) {
    try {
      final String trimmed = text.trim();
      if (!trimmed.startsWith('{')) return false;
      jsonDecode(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// POSTs [body] to [url], but stops awaiting (and throws
  /// [CancellationException]) as soon as [cancelToken] fires, so the caller
  /// can move on immediately. The underlying HTTP request is not aborted —
  /// the remote provider keeps running — but for local VRAM the real kill
  /// happens in [ProcessRunner]; this only makes remote stops non-blocking.
  Future<http.Response> _postOrCancel(
    Uri url, {
    required Map<String, String> headers,
    required String body,
    CancelToken? cancelToken,
  }) {
    final Future<http.Response> request = _httpClient.post(
      url,
      headers: headers,
      body: body,
    );
    if (cancelToken == null) {
      return request;
    }

    // Race via a Completer so the losing branch is a no-op instead of an
    // unhandled async error.
    final Completer<http.Response> completer = Completer<http.Response>();
    request.then(
      (http.Response r) {
        if (!completer.isCompleted) {
          completer.complete(r);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
    );
    cancelToken.onCancel.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          const CancellationException('Remote caption cancelled.'),
        );
      }
    });
    return completer.future;
  }

  /// Visible for testing. Builds the chat completions URL from a base URL.
  String buildUrl(String baseUrl) {
    if (baseUrl.endsWith('chat/completions')) {
      return baseUrl;
    } else if (baseUrl.endsWith('/')) {
      return '${baseUrl}chat/completions';
    } else {
      return '$baseUrl/chat/completions';
    }
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
