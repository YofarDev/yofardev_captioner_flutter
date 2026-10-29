/// Produces compact JSON without extra whitespace. Shared by the structured
/// caption models (Ideogram4 / MOSS layout) whose storage format is a
/// key-order-pinned single-line JSON string.
String compactJson(Map<String, dynamic> data) {
  final StringBuffer buffer = StringBuffer();
  _writeCompactJson(buffer, data);
  return buffer.toString();
}

void _writeCompactJson(StringBuffer buffer, Object? value) {
  if (value == null) {
    buffer.write('null');
  } else if (value is String) {
    buffer.write('"${_escapeString(value)}"');
  } else if (value is num || value is bool) {
    buffer.write(value);
  } else if (value is List) {
    buffer.write('[');
    for (int i = 0; i < value.length; i++) {
      if (i > 0) buffer.write(',');
      _writeCompactJson(buffer, value[i]);
    }
    buffer.write(']');
  } else if (value is Map<String, dynamic>) {
    buffer.write('{');
    int i = 0;
    for (final MapEntry<String, dynamic> entry in value.entries) {
      if (i > 0) buffer.write(',');
      buffer.write('"${_escapeString(entry.key)}":');
      _writeCompactJson(buffer, entry.value);
      i++;
    }
    buffer.write('}');
  }
}

String _escapeString(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r')
    .replaceAll('\t', '\\t');
