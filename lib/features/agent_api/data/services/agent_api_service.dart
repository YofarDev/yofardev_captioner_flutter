import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_data.dart';
import '../../../../core/models/caption_database.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../../core/models/llm_configs.dart';
import '../../../../core/services/cache_service.dart';
import '../../../image_list/image_list.dart';
import '../../../llm_config/llm_config.dart';
import '../../../tab_manager/tab_manager.dart';
import 'agent_caption_write_service.dart';

/// Local REST API for external AI agents (Claude Code, ZCode, scripts).
///
/// Listens on 127.0.0.1 only and authenticates every route except
/// `/api/health` with a bearer token persisted in [CacheService]. Port and
/// token are mirrored into an `agent-api.json` discovery file inside the
/// application support directory so agents can find them on their own.
///
/// Caption writes go through the live [CaptionSessionService] when the folder
/// is open in a tab — the app rewrites `db.json` from in-memory state on every
/// save, so routing external writes through the session is what keeps them
/// from being clobbered. Folders that aren't open in any tab are updated by
/// a direct read-modify-write of `db.json`.
class AgentApiService {
  AgentApiService({
    String? discoveryDirPath,
    CacheService? cacheService,
    required ILlmConfigRepository llmConfigRepository,
    AgentCaptionWriteService? writeService,
  }) : _discoveryDirPath = discoveryDirPath,
       _cacheService = cacheService ?? const CacheService(),
       _llmConfigRepository = llmConfigRepository,
       _writeService = writeService ?? AgentCaptionWriteService();

  final CacheService _cacheService;
  final ILlmConfigRepository _llmConfigRepository;
  final AgentCaptionWriteService _writeService;

  static const String _discoveryFileName = 'agent-api.json';
  static const String _defaultModel = 'agent';

  final Logger _logger = Logger('AgentApiService');
  final String? _discoveryDirPath;

  HttpServer? _server;
  String? _token;
  String? _appVersion;

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get token => _token;

  Future<void> start() async {
    if (_server != null) return;

    _token = await _cacheService.loadAgentApiToken();
    if (_token == null || _token!.isEmpty) {
      _token = const Uuid().v4();
      await _cacheService.saveAgentApiToken(_token!);
    }

    final int desiredPort = await _cacheService.loadAgentApiPort();
    try {
      _server = await shelf_io.serve(
        _buildHandler(),
        InternetAddress.loopbackIPv4,
        desiredPort,
      );
    } on SocketException {
      // Configured port busy (stale instance, another app) — fall back to an
      // ephemeral port; the discovery file always carries the real one.
      _server = await shelf_io.serve(
        _buildHandler(),
        InternetAddress.loopbackIPv4,
        0,
      );
    }

    await _writeDiscoveryFile();
    _logger.info('Agent API listening on http://127.0.0.1:${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    await _deleteDiscoveryFile();
    _logger.info('Agent API stopped');
  }

  /// Restarts when already running so a port change applies immediately.
  Future<void> restart() async {
    if (_server == null) return;
    await stop();
    await start();
  }

  Future<String> discoveryFilePath() async => (await _discoveryFile()).path;

  Handler _buildHandler() {
    final Router router = Router()
      ..get('/api/health', _handleHealth)
      ..get('/api/prompts', _handlePrompts)
      ..get('/api/folders', _handleFolders)
      ..get('/api/images', _handleImages)
      ..post('/api/captions', _handlePostCaption)
      ..post('/api/folders/refresh', _handleRefreshFolder);

    return const Pipeline()
        .addMiddleware(_logRequests)
        .addMiddleware(_requireAuth)
        .addMiddleware(_catchErrors)
        .addHandler(router.call);
  }

  // ---------------------------------------------------------------------------
  // Middleware
  // ---------------------------------------------------------------------------

  Middleware get _logRequests =>
      (Handler inner) => (Request request) async {
        final Response response = await inner(request);
        _logger.info(
          '${request.method} /${request.url.path} -> ${response.statusCode}',
        );
        return response;
      };

  Middleware get _requireAuth =>
      (Handler inner) => (Request request) {
        if (request.url.path == 'api/health') {
          return inner(request);
        }
        final String? authorization = request.headers['authorization'];
        if (authorization == null || authorization != 'Bearer $_token') {
          return _jsonResponse(401, <String, dynamic>{
            'error': 'unauthorized',
            'hint':
                'send "Authorization: Bearer <token>" — find the token in '
                'the agent-api.json discovery file or the app settings',
          });
        }
        return inner(request);
      };

  Middleware get _catchErrors =>
      (Handler inner) => (Request request) async {
        try {
          return await inner(request);
        } catch (e, st) {
          _logger.severe(
            'Agent API error on ${request.method} /${request.url.path}',
            e,
            st,
          );
          return _jsonResponse(500, <String, dynamic>{
            'error': 'internal error',
          });
        }
      };

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Future<Response> _handleHealth(Request request) async {
    return _jsonResponse(200, <String, dynamic>{
      'status': 'ok',
      'app': 'yofardev_captioner',
      'version': await _loadAppVersion(),
    });
  }

  Future<Response> _handlePrompts(Request request) async {
    final Either<Failure, LlmConfigs?> result = await _llmConfigRepository
        .loadLlmConfigs();
    if (result.isLeft()) {
      final Failure f = result.getLeft().toNullable()!;
      _logger.severe('GET /api/prompts failed to load LLM configs: $f');
      return _jsonResponse(500, <String, dynamic>{
        'error': 'Failed to load LLM configuration',
        'detail': failureMessage(f),
      });
    }
    // Before anything is saved, mirror the defaults the settings UI shows.
    final LlmConfigs configs =
        result.getRight().toNullable() ?? const LlmConfigs.defaults();
    return _jsonResponse(200, <String, dynamic>{
      'prompts': configs.prompts,
      'selectedPrompt': configs.selectedPrompt,
    });
  }

  Future<Response> _handleFolders(Request request) async {
    final TabSessionRegistry? registry = _registryIfReady();
    if (registry == null) {
      return _jsonResponse(503, <String, dynamic>{'error': 'app not ready'});
    }
    final List<TabSessionInfo> tabs = registry.tabs;
    return _jsonResponse(200, <String, dynamic>{
      'tabs': <Map<String, dynamic>>[
        for (final TabSessionInfo tab in tabs)
          <String, dynamic>{
            'id': tab.id,
            'folderPath': tab.folderPath,
            'displayName': tab.displayName,
            'active': tab.isActive,
          },
      ],
    });
  }

  Future<Response> _handleImages(Request request) async {
    final String? folder = request.url.queryParameters['folder'];
    if (folder == null || folder.isEmpty) {
      return _jsonResponse(400, <String, dynamic>{
        'error': 'missing "folder" query parameter',
      });
    }
    final String normalized = p.normalize(folder);
    if (!await Directory(normalized).exists()) {
      return _jsonResponse(404, <String, dynamic>{
        'error': 'folder not found',
        'folder': normalized,
      });
    }

    final CaptionSessionService? session = _openSessionFor(normalized);
    if (session != null) {
      final ImageListState state = session.current.state;
      return _jsonResponse(200, <String, dynamic>{
        'folder': normalized,
        'categories': state.categories,
        'activeCategory': state.activeCategory,
        'images': <Map<String, dynamic>>[
          for (final AppImage image in state.images)
            _writeService.imageJson(
              image,
              guidance: state.imageGuidance[image.image.path],
            ),
        ],
      });
    }

    final CaptionFileStore fileUtils = locator<CaptionFileStore>();
    final Either<Failure, CaptionDatabase> dbResult = await fileUtils.readDb(
      normalized,
    );
    final CaptionDatabase? db = dbResult.getRight().toNullable();
    if (db == null) {
      final Failure f = dbResult.getLeft().toNullable()!;
      _logger.severe('GET folder images: db.json unreadable: $f');
      return _jsonResponse(500, <String, dynamic>{
        'error': 'database could not be read',
        'folder': normalized,
        'detail': failureMessage(f),
      });
    }
    return _jsonResponse(
      200,
      await _imagesPayloadFromDisk(fileUtils, normalized, db),
    );
  }

  Future<Response> _handlePostCaption(Request request) {
    return _writeService.serializeWrites(() async {
      Map<String, dynamic> body;
      try {
        body = await _readJsonBody(request);
      } on FormatException {
        return _jsonResponse(400, <String, dynamic>{
          'error': 'invalid JSON body',
        });
      }

      final String? folder = body['folder'] as String?;
      final String? filename = body['filename'] as String?;
      final String? text = body['text'] as String?;
      if (folder == null || filename == null || text == null) {
        return _jsonResponse(400, <String, dynamic>{
          'error': '"folder", "filename" and "text" are required',
        });
      }
      if (text.isEmpty) {
        return _jsonResponse(400, <String, dynamic>{
          'error': '"text" must not be empty',
        });
      }

      final String normalizedFolder = p.normalize(folder);
      final String category = (body['category'] as String?) ?? 'default';
      final String model = (body['model'] as String?) ?? _defaultModel;

      final dynamic rawTags = body['tags'];
      if (rawTags != null && rawTags is! List) {
        return _jsonResponse(400, <String, dynamic>{
          'error': '"tags" must be an array of strings',
        });
      }
      final List<String>? extraTags = rawTags is List
          ? rawTags.whereType<String>().toList()
          : null;

      final File imageFile = File(p.join(normalizedFolder, filename));
      if (!await imageFile.exists()) {
        return _jsonResponse(404, <String, dynamic>{
          'error': 'image not found on disk',
          'path': imageFile.path,
        });
      }

      final CaptionSessionService? session = _openSessionFor(normalizedFolder);
      if (session != null) {
        return await _writeService.writeViaSession(
          session,
          filename: filename,
          category: category,
          text: text,
          model: model,
          extraTags: extraTags,
        );
      }
      return await _writeService.writeViaFile(
        normalizedFolder,
        filename: filename,
        category: category,
        text: text,
        model: model,
        extraTags: extraTags,
      );
    });
  }

  Future<Response> _handleRefreshFolder(Request request) async {
    Map<String, dynamic> body;
    try {
      body = await _readJsonBody(request);
    } on FormatException {
      return _jsonResponse(400, <String, dynamic>{
        'error': 'invalid JSON body',
      });
    }
    final String? folder = body['folder'] as String?;
    if (folder == null || folder.isEmpty) {
      return _jsonResponse(400, <String, dynamic>{
        'error': '"folder" is required',
      });
    }
    final String normalized = p.normalize(folder);

    final TabSessionRegistry? registry = _registryIfReady();
    final TabSessionInfo? tab = registry?.tabForFolder(normalized);
    final CaptionSessionService? session = tab == null
        ? null
        : registry!.sessionFor(tab.id);
    if (session == null) {
      return _jsonResponse(200, <String, dynamic>{
        'ok': true,
        'refreshed': false,
        'note': 'folder is not open in any tab',
      });
    }
    await session.onFolderPicked(normalized, force: true);
    return _jsonResponse(200, <String, dynamic>{'ok': true, 'refreshed': true});
  }

  TabSessionRegistry? _registryIfReady() {
    if (!locator.isRegistered<TabSessionRegistry>()) return null;
    return locator<TabSessionRegistry>();
  }

  CaptionSessionService? _openSessionFor(String folder) {
    final TabSessionRegistry? registry = _registryIfReady();
    if (registry == null) return null;
    final TabSessionInfo? tab = registry.tabForFolder(folder);
    if (tab == null) return null;
    final CaptionSessionService session = registry.sessionFor(tab.id);
    // A session that is mid-scan still points at its previous folder — treat
    // that as "not open" so callers fall through to the disk path.
    if (session.current.state.folderPath != folder) return null;
    return session;
  }

  Future<Map<String, dynamic>> _imagesPayloadFromDisk(
    CaptionFileStore fileUtils,
    String folder,
    CaptionDatabase db,
  ) async {
    final Map<String, CaptionData> byName = <String, CaptionData>{
      for (final CaptionData data in db.images) data.filename: data,
    };

    final List<Map<String, dynamic>> images = <Map<String, dynamic>>[];
    for (final FileSystemEntity entity in Directory(folder).listSync()) {
      if (entity is! File) continue;
      final String extension = p.extension(entity.path).toLowerCase();
      if (extension != '.jpg' &&
          extension != '.png' &&
          extension != '.jpeg' &&
          extension != '.webp') {
        continue;
      }
      final String filename = p.basename(entity.path);
      final CaptionData? data = byName[filename];
      images.add(<String, dynamic>{
        'id': data?.id,
        'filename': filename,
        'path': entity.path,
        'captions':
            data?.captions.map(
              (String key, CaptionEntry value) =>
                  MapEntry<String, dynamic>(key, value.toJson()),
            ) ??
            <String, dynamic>{},
        'tags': data?.tags ?? <String>[],
        'guidance': data == null ? '' : (db.imageGuidance[data.id] ?? ''),
      });
    }
    images.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          fileUtils.compareNatural(a['path'] as String, b['path'] as String),
    );

    return <String, dynamic>{
      'folder': folder,
      'categories': db.categories,
      'activeCategory': db.activeCategory ?? 'default',
      'images': images,
    };
  }

  Future<Map<String, dynamic>> _readJsonBody(Request request) async {
    final String content = await request.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<String> _loadAppVersion() async {
    if (_appVersion != null) return _appVersion!;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {
      _appVersion = 'unknown';
    }
    return _appVersion!;
  }

  Future<File> _discoveryFile() async {
    final String dirPath =
        _discoveryDirPath ?? (await getApplicationSupportDirectory()).path;
    return File(p.join(dirPath, _discoveryFileName));
  }

  Future<void> _writeDiscoveryFile() async {
    try {
      final File file = await _discoveryFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'port': _server?.port,
          'token': _token,
          'pid': pid,
        }),
      );
    } catch (e) {
      _logger.warning('Failed to write agent API discovery file: $e');
    }
  }

  Future<void> _deleteDiscoveryFile() async {
    try {
      final File file = await _discoveryFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Discovery file cleanup is best-effort.
    }
  }

  static Response _jsonResponse(int status, Map<String, dynamic> body) =>
      AgentCaptionWriteService.jsonResponse(status, body);
}
