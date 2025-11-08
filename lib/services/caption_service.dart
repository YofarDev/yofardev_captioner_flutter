// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/llm_config.dart';

class CaptionService {
  Future<String> getCaption(LlmConfig config, File image, String prompt) async {
    final Uint8List bytes = await image.readAsBytes();
    final String base64Image = base64Encode(bytes);

    final String url = config.url.endsWith('chat/completions')
        ? config.url
        : config.url.endsWith('/')
        ? '${config.url}chat/completions'
        : '${config.url}/chat/completions';

    final http.Response response = await http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'model': config.model,
        'stream': false,
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
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['choices'] != null &&
          (decoded['choices'] as List<dynamic>).isNotEmpty) {
        final dynamic message = decoded['choices'][0]['message'];
        if (message != null && message['content'] is String) {
          return message['content'] as String;
        }
      }

      throw Exception('Invalid response format: ${response.body}');
    } else {
      debugPrint('Error response: ${response.body}');
      throw Exception(
        'Failed to load caption (${response.statusCode}): ${response.body}',
      );
    }
  }
}
