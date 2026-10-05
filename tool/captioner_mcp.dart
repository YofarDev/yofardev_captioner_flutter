#!/usr/bin/env dart
// Stdio MCP server proxying Yofardev Captioner's local Agent API.
//
// Register once (Claude Code):
//   claude mcp add -s user captioner dart /path/to/yofardev_captioner/tool/captioner_mcp.dart
//
// The app's port and bearer token are resolved on every tool call from the
// agent-api.json discovery file the app writes while running, so the
// registration itself never needs credentials and survives port changes.
//
// Speaks the minimal MCP stdio subset: initialize, ping, tools/list,
// tools/call over newline-delimited JSON-RPC 2.0. No external packages.

import 'dart:convert';
import 'dart:io';

const String _serverName = 'yofardev-captioner';
const String _serverVersion = '1.0.0';
const String _defaultProtocolVersion = '2025-06-18';

Future<void> main() async {
  try {
    await for (final String line in stdin
        .transform<String>(utf8.decoder)
        .transform<String>(const LineSplitter())) {
      await _handleLine(line);
    }
  } on FileSystemException {
    // Client closed the pipe — shut down quietly.
    exit(0);
  }
}

Future<void> _handleLine(String line) async {
  if (line.trim().isEmpty) return;
  dynamic decoded;
  try {
    decoded = jsonDecode(line);
  } on FormatException {
    return;
  }
  if (decoded is! Map<String, dynamic>) return;

  final Object? id = decoded['id'] as Object?;
  if (id == null) return; // notification — nothing to answer

  final String method = decoded['method'] as String? ?? '';
  final Map<String, dynamic> params =
      (decoded['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};

  try {
    switch (method) {
      case 'initialize':
        await _send(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, dynamic>{
            'protocolVersion':
                params['protocolVersion'] as String? ?? _defaultProtocolVersion,
            'capabilities': <String, dynamic>{
              'tools': <String, dynamic>{'listChanged': false},
            },
            'serverInfo': <String, dynamic>{
              'name': _serverName,
              'version': _serverVersion,
            },
          },
        });
      case 'ping':
        await _send(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, dynamic>{},
        });
      case 'tools/list':
        await _send(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, dynamic>{'tools': _toolDefinitions()},
        });
      case 'tools/call':
        final _ToolResult result = await _callTool(
          params['name'] as String? ?? '',
          (params['arguments'] as Map<String, dynamic>?) ??
              <String, dynamic>{},
        );
        await _send(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, dynamic>{
            'content': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'text', 'text': result.text},
            ],
            'isError': result.isError,
          },
        });
      default:
        await _send(_error(id, -32601, 'Method not found: $method'));
    }
  } catch (e, st) {
    stderr.writeln('captioner_mcp: $method failed: $e\n$st');
    await _send(_error(id, -32603, 'Internal error: $e'));
  }
}

Future<void> _send(Map<String, dynamic> message) async {
  stdout.writeln(jsonEncode(message));
  await stdout.flush();
}

Map<String, dynamic> _error(Object id, int code, String message) =>
    <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, dynamic>{'code': code, 'message': message},
    };

// -----------------------------------------------------------------------------
// Tools
// -----------------------------------------------------------------------------

List<Map<String, dynamic>> _toolDefinitions() =>
    <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'status',
        'description': 'Check whether the Yofardev Captioner desktop app is '
            'running and its Agent API is reachable.',
        'inputSchema': _schema(<String, dynamic>{}),
      },
      <String, dynamic>{
        'name': 'list_prompts',
        'description': 'List the captioning prompts saved in Yofardev '
            'Captioner, plus the currently selected one. Follow one of these '
            'prompts when writing captions unless the user asks otherwise.',
        'inputSchema': _schema(<String, dynamic>{}),
      },
      <String, dynamic>{
        'name': 'list_folders',
        'description': 'List the image folders currently open as tabs in '
            'Yofardev Captioner.',
        'inputSchema': _schema(<String, dynamic>{}),
      },
      <String, dynamic>{
        'name': 'list_images',
        'description': 'List the images of a folder with their existing '
            "captions, tags and the folder's categories. Works for folders "
            'open in the app and for arbitrary folders on disk. Each entry '
            'includes the absolute file path — read the image file yourself '
            '(you have vision) to produce its caption.',
        'inputSchema': _schema(<String, dynamic>{
          'folder': <String, dynamic>{
            'type': 'string',
            'description': 'Absolute path of the image folder.',
          },
        }, required: <String>['folder']),
      },
      <String, dynamic>{
        'name': 'write_caption',
        'description': 'Write a caption for one image. Generate the caption '
            'text yourself by looking at the image, optionally following a '
            'prompt from list_prompts. Routing through the app keeps db.json '
            'consistent with the UI.',
        'inputSchema': _schema(<String, dynamic>{
          'folder': <String, dynamic>{
            'type': 'string',
            'description': 'Absolute path of the image folder.',
          },
          'filename': <String, dynamic>{
            'type': 'string',
            'description': 'Image filename within the folder, e.g. "cat.jpg".',
          },
          'text': <String, dynamic>{
            'type': 'string',
            'description': 'The caption text you produced.',
          },
          'category': <String, dynamic>{
            'type': 'string',
            'description': 'Caption category (defaults to "default"). Valid '
                'values come back in the error on a wrong pick.',
          },
          'model': <String, dynamic>{
            'type': 'string',
            'description': 'Name recorded as the caption author '
                '(defaults to "agent"; pass your agent name).',
          },
          'tags': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
            'description': "Optional tags to merge into the image's tags.",
          },
        }, required: <String>['folder', 'filename', 'text']),
      },
      <String, dynamic>{
        'name': 'refresh_folder',
        'description': 'Force the app to re-scan a folder so images added or '
            'renamed externally show up.',
        'inputSchema': _schema(<String, dynamic>{
          'folder': <String, dynamic>{
            'type': 'string',
            'description': 'Absolute path of the image folder.',
          },
        }, required: <String>['folder']),
      },
    ];

Map<String, dynamic> _schema(
  Map<String, dynamic> properties, {
  List<String> required = const <String>[],
}) => <String, dynamic>{
    'type': 'object',
    'properties': properties,
    if (required.isNotEmpty) 'required': required,
  };

Future<_ToolResult> _callTool(
  String name,
  Map<String, dynamic> args,
) async {
  switch (name) {
    case 'status':
      return await _api('GET', '/api/health');
    case 'list_prompts':
      return await _api('GET', '/api/prompts');
    case 'list_folders':
      return await _api('GET', '/api/folders');
    case 'list_images':
      final String? folder = args['folder'] as String?;
      if (folder == null || folder.isEmpty) {
        return const _ToolResult.error('"folder" is required');
      }
      return await _api(
        'GET',
        '/api/images?folder=${Uri.encodeQueryComponent(folder)}',
      );
    case 'refresh_folder':
      final String? folder = args['folder'] as String?;
      if (folder == null || folder.isEmpty) {
        return const _ToolResult.error('"folder" is required');
      }
      return await _api(
        'POST',
        '/api/folders/refresh',
        body: <String, dynamic>{'folder': folder},
      );
    case 'write_caption':
      final String? folder = args['folder'] as String?;
      final String? filename = args['filename'] as String?;
      final String? text = args['text'] as String?;
      if (folder == null || filename == null || text == null) {
        return const _ToolResult.error(
          '"folder", "filename" and "text" are required',
        );
      }
      final Map<String, dynamic> body = <String, dynamic>{
        'folder': folder,
        'filename': filename,
        'text': text,
      };
      final String? category = args['category'] as String?;
      if (category != null) body['category'] = category;
      final String? model = args['model'] as String?;
      if (model != null) body['model'] = model;
      final dynamic tags = args['tags'];
      if (tags is List) body['tags'] = tags.whereType<String>().toList();
      return await _api('POST', '/api/captions', body: body);
    default:
      return _ToolResult.error('Unknown tool "$name"');
  }
}

// -----------------------------------------------------------------------------
// Agent API client
// -----------------------------------------------------------------------------

Future<_ToolResult> _api(
  String method,
  String path, {
  Map<String, dynamic>? body,
}) async {
  final Map<String, dynamic>? discovery = await _loadDiscovery();
  if (discovery == null) {
    return const _ToolResult.error(
      'Yofardev Captioner does not appear to be running: no agent-api.json '
      'discovery file found. Ask the user to start the app, then retry.',
    );
  }
  final int port = (discovery['port'] as num?)?.toInt() ?? 0;
  final String? token = discovery['token'] as String?;
  if (port == 0 || token == null) {
    return const _ToolResult.error(
      'Malformed agent-api.json discovery file — restart the app.',
    );
  }

  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.openUrl(
      method,
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(body));
    }
    final HttpClientResponse response = await request.close();
    final String text = await utf8.decoder.bind(response).join();

    if (response.statusCode == 200) {
      try {
        final dynamic decoded = jsonDecode(text);
        return _ToolResult.ok(
          const JsonEncoder.withIndent('  ').convert(decoded),
        );
      } on FormatException {
        return _ToolResult.ok(text);
      }
    }
    return _ToolResult.error('HTTP ${response.statusCode}: $text');
  } on SocketException catch (e) {
    return _ToolResult.error(
      'Cannot reach Yofardev Captioner on 127.0.0.1:$port '
      '(${e.osError?.message ?? e.message}). Is the app running?',
    );
  } on HttpException catch (e) {
    return _ToolResult.error('HTTP error talking to the app: $e.message');
  } finally {
    client.close();
  }
}

/// Reads the discovery file the app maintains while the Agent API runs.
/// Never cached — the app may restart on a different port.
Future<Map<String, dynamic>?> _loadDiscovery() async {
  final String? home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) return null;

  final List<String> candidates = <String>[
    if (Platform.isMacOS)
      '$home/Library/Application Support/fr.yofardev.yofardevCaptioner/agent-api.json'
    else if (Platform.isLinux)
      '$home/.local/share/yofardev_captioner/agent-api.json'
    else if (Platform.isWindows)
      '${Platform.environment['APPDATA'] ?? ''}\\yofardev_captioner\\agent-api.json',
  ];

  for (final String path in candidates) {
    if (path.isEmpty) continue;
    try {
      final File file = File(path);
      if (await file.exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {
      // Unreadable candidate — try the next platform path.
    }
  }
  return null;
}

class _ToolResult {
  const _ToolResult(this.text, {required this.isError});

  const _ToolResult.ok(String text) : this(text, isError: false);

  const _ToolResult.error(String text) : this(text, isError: true);

  final String text;
  final bool isError;
}
