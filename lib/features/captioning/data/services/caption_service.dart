import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/caption/caption_request.dart';
import '../models/caption/caption_response.dart';
import '../models/caption/content.dart';
import '../models/caption/message.dart';
import '../../llm_config/data/models/llm_config.dart';
import '../../llm_config/data/models/llm_provider_type.dart';
import '../../../image_operations/data/utils/image_utils.dart';
import '../core/config/service_locator.dart';

class CaptionService {
  final Logger _logger = locator<Logger>();

  Future<String> getCaption(LlmConfig config, File image, String prompt) {
    if (config.providerType == LlmProviderType.localMlx) {
      return _getLocalCaption(config, image, prompt);
    } else {
      return _getRemoteCaption(config, image, prompt);
    }
  }

  Future<String> _getLocalCaption(
    LlmConfig config,
    File image,
    String prompt,
  ) async {
    final List<String> arguments = <String>[
      '--model',
      config.model,
      '--temperature',
      '0.0',
      '--prompt',
      prompt,
      '--image',
      image.path,
    ];

    try {
      final String executable =
          (config.mlxPath?.isNotEmpty ?? false)
              ? config.mlxPath!
              : 'mlx_vlm.generate';
      final ProcessResult result = await Process.run(
        executable,
        arguments,
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
          return match.group(1)!.trim();
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
    }
  }

  Future<String> _getRemoteCaption(
    LlmConfig config,
    File image,
    String prompt,
  ) async {
    File? imageToSend;
    try {
      if (config.url == null || config.apiKey == null) {
        throw ApiException(
          'URL and API Key are required for remote providers.',
        );
      }
      imageToSend = await ImageUtils.resizeImageIfNecessary(image);
      final Uint8List bytes = await imageToSend.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final String url = _buildUrl(config.url!);

      final CaptionRequest request = CaptionRequest(
        model: config.model,
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

      final http.Response response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        try {
          final CaptionResponse captionResponse = CaptionResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          );
          if (captionResponse.choices.isNotEmpty) {
            return captionResponse.choices.first.message.content;
          } else {
            throw ApiException('Invalid response format: ${response.body}');
          }
        } catch (e) {
          _logger.severe('Error decoding response: $e');
          throw ApiException('Failed to decode response: $e');
        }
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

  String _buildUrl(String baseUrl) {
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
