import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/llm_configs.dart';
import '../../domain/repositories/llm_config_repository.dart';

/// SharedPreferences-backed implementation of [ILlmConfigRepository].
class LlmConfigService implements ILlmConfigRepository {
  static const String _llmConfigsKey = 'llm_configs';

  @override
  Future<void> saveLlmConfigs(LlmConfigs configs) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(configs.toJson());
    await prefs.setString(_llmConfigsKey, jsonString);
  }

  @override
  Future<LlmConfigs?> loadLlmConfigs() async {
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
