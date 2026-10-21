import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists UI-only layer titles per image, keyed by absolute image path.
///
/// Titles are display labels that never enter the caption JSON. They are keyed
/// by element *index*, so they stay correct as long as the caption element
/// order is only changed through the editor (which persists titles atomically
/// with each reorder). If the caption JSON is reordered by an external tool,
/// titles may reattach to the wrong element — re-set them in the editor.
// ponytail: index-keyed, not content-fingerprinted; reordering outside the
// editor can misattach titles. Upgrade to per-element stable ids if that bites.
class LayerTitleStore {
  const LayerTitleStore();

  static const String _prefix = 'layerTitles:';

  Future<Map<int, String>> load(String imagePath) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefix + imagePath);
    if (raw == null || raw.isEmpty) {
      return const <int, String>{};
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (String k, dynamic v) =>
            MapEntry<int, String>(int.parse(k), v as String),
      );
    } catch (_) {
      return const <int, String>{};
    }
  }

  Future<void> save(String imagePath, Map<int, String> titles) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = _prefix + imagePath;
    if (titles.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final Map<String, String> stringified = titles.map(
      (int k, String v) => MapEntry<String, String>(k.toString(), v),
    );
    await prefs.setString(key, jsonEncode(stringified));
  }
}
