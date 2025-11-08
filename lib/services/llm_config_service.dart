import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/llm_configs.dart';

class LlmConfigService {
  static const String _llmConfigsKey = 'llm_configs';

  static Future<void> saveLlmConfigs(LlmConfigs configs) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(configs.toJson());
    await prefs.setString(_llmConfigsKey, jsonString);
  }

  static Future<LlmConfigs?> loadLlmConfigs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_llmConfigsKey);
    if (jsonString != null) {
      return LlmConfigs.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    }
    return null;
  }
}
