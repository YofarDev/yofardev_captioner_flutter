import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/caption/caption_request.dart';
import '../models/caption/caption_response.dart';
import '../models/caption/content.dart';
import '../models/caption/message.dart';
import '../models/llm_config.dart';
import 'service_locator.dart';

class CaptionService {
  final Logger _logger = locator<Logger>();

  Future<String> getCaption(LlmConfig config, File image, String prompt) async {
    final Uint8List bytes = await image.readAsBytes();
    final String base64Image = base64Encode(bytes);

    final String url = _buildUrl(config.url);

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
