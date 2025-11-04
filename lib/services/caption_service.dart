import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/llm_config.dart';

class CaptionService {
  Future<String> getCaption(
    LlmConfig config,
    File image,
    String prompt,
  ) async {
    final Uint8List bytes = await image.readAsBytes();
    final String base64Image = base64Encode(bytes);

    final http.Response response = await http.post(
      Uri.parse(config.url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode(<String, Object>{
        'model': config.model,
        'messages': <Map<String, Object>>[
          <String, Object>{
            'role': 'user',
            'content': <Map<String, Object>>[
              <String, String>{'type': 'text', 'text': prompt},
              <String, Object>{
                'type': 'image_url',
                'image_url': <String, String>{
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 300,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      // ignore: avoid_dynamic_calls
      return decoded['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Failed to load caption');
    }
  }
}
