import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_data.dart';
import '../../../../core/models/caption_database.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../caption_session/caption_session.dart';

/// Caption write paths for the Agent API: through a live tab session when the
/// folder is open, otherwise via a direct read-modify-write of `db.json`.
///
/// The app rewrites `db.json` from in-memory state on every save, so routing
/// external writes through the session is what keeps them from being
/// clobbered. All writes are serialized so concurrent requests can't
/// interleave read-modify-write cycles.
class AgentCaptionWriteService {
  final Logger _logger = Logger('AgentCaptionWriteService');

  /// Serializes caption writes so concurrent requests can't interleave
  /// read-modify-write cycles on db.json.
  Future<void> _writeQueue = Future<void>.value();

  /// Runs [action] exclusively with respect to other caption writes.
  Future<Response> serializeWrites(Future<Response> Function() action) {
    final Future<Response> next = _writeQueue.then((_) => action());
    _writeQueue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<Response> writeViaSession(
    CaptionSessionService session, {
    required String filename,
    required String category,
    required String text,
    required String model,
    List<String>? extraTags,
  }) async {
    final ImageListState state = session.current.state;
    if (!state.categories.contains(category)) {
      return jsonResponse(400, <String, dynamic>{
        'error': 'unknown category "$category"',
        'categories': state.categories,
      });
    }

    AppImage? target;
    for (final AppImage image in state.images) {
      if (p.basename(image.image.path) == filename) {
        target = image;
        break;
      }
    }
    if (target == null) {
      return jsonResponse(404, <String, dynamic>{
        'error':
            'image not loaded in the open tab — POST /api/folders/refresh '
            'first, then retry',
        'filename': filename,
      });
    }

    final AppImage updated = target.copyWith(
      captions: <String, CaptionEntry>{
        ...target.captions,
        category: CaptionEntry(
          text: text,
          model: model,
          timestamp: DateTime.now(),
        ),
      },
      lastModified: DateTime.now(),
      tags: extraTags == null
          ? target.tags
          : mergedTags(target.tags, extraTags),
    );
    await session.updateImage(image: updated);
    return jsonResponse(200, <String, dynamic>{
      'ok': true,
      'mode': 'live',
      'image': imageJson(
        updated,
        guidance: session.current.state.imageGuidance[updated.image.path],
      ),
    });
  }

  Future<Response> writeViaFile(
    String folder, {
    required String filename,
    required String category,
    required String text,
    required String model,
    List<String>? extraTags,
  }) async {
    final CaptionFileStore fileUtils = locator<CaptionFileStore>();
    final Either<Failure, CaptionDatabase> dbResult = await fileUtils.readDb(
      folder,
    );
    final CaptionDatabase? db = dbResult.getRight().toNullable();
    if (db == null) {
      final Failure f = dbResult.getLeft().toNullable()!;
      _logger.severe('POST /api/captions: db.json unreadable: $f');
      return jsonResponse(500, <String, dynamic>{
        'error': 'database could not be read',
        'folder': folder,
        'detail': failureMessage(f),
      });
    }
    if (!db.categories.contains(category)) {
      return jsonResponse(400, <String, dynamic>{
        'error': 'unknown category "$category"',
        'categories': db.categories,
      });
    }

    CaptionData? existing;
    for (final CaptionData data in db.images) {
      if (data.filename == filename) {
        existing = data;
        break;
      }
    }

    // Rebuild rather than mutate: deserialized maps/lists may be unmodifiable.
    final CaptionData updated = CaptionData(
      id: existing?.id ?? const Uuid().v4(),
      filename: filename,
      captions: <String, CaptionEntry>{
        ...?existing?.captions,
        category: CaptionEntry(
          text: text,
          model: model,
          timestamp: DateTime.now(),
        ),
      },
      lastModified: DateTime.now(),
      tags: mergedTags(existing?.tags ?? const <String>[], extraTags),
    );
    if (existing == null) {
      db.images.add(updated);
    } else {
      db.images[db.images.indexOf(existing)] = updated;
    }

    await fileUtils.writeDb(folder, db);
    return jsonResponse(200, <String, dynamic>{
      'ok': true,
      'mode': 'file',
      'created': existing == null,
      'image': <String, dynamic>{
        'id': updated.id,
        'filename': updated.filename,
        'path': p.join(folder, filename),
        'captions': updated.captions.map(
          (String key, CaptionEntry value) =>
              MapEntry<String, dynamic>(key, value.toJson()),
        ),
        'tags': updated.tags,
      },
    });
  }

  List<String> mergedTags(List<String> current, List<String>? extra) {
    if (extra == null || extra.isEmpty) return current;
    return <String>[
      ...current,
      for (final String tag in extra)
        if (!current.contains(tag)) tag,
    ];
  }

  /// Canonical image JSON for the agent API. The disk listing path has no
  /// [AppImage] (only a db [CaptionData] plus the file on disk), so both
  /// paths funnel through [imageJsonFrom] — one shape, one place.
  Map<String, dynamic> imageJsonFrom({
    required String? id,
    required String path,
    required Map<String, CaptionEntry> captions,
    required List<String> tags,
    String? guidance,
  }) => <String, dynamic>{
    'id': id,
    'filename': p.basename(path),
    'path': path,
    'captions': captions.map(
      (String key, CaptionEntry value) =>
          MapEntry<String, dynamic>(key, value.toJson()),
    ),
    'tags': tags,
    'guidance': guidance ?? '',
  };

  Map<String, dynamic> imageJson(AppImage image, {String? guidance}) =>
      imageJsonFrom(
        id: image.id,
        path: image.image.path,
        captions: image.captions,
        tags: image.tags,
        guidance: guidance,
      );

  static Response jsonResponse(int status, Map<String, dynamic> body) =>
      Response(status, body: jsonEncode(body), headers: _jsonHeaders);

  static const Map<String, String> _jsonHeaders = <String, String>{
    'content-type': 'application/json; charset=utf-8',
  };
}
