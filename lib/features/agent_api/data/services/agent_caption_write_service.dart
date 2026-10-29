import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import '../../../../core/models/moss_format.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../../core/services/moss_conversion_service.dart';
import '../../../caption_session/caption_session.dart';

/// Caption write paths for the Agent API: through a live tab session when the
/// folder is open, otherwise via a direct read-modify-write of `db.json`.
///
/// The app rewrites `db.json` from in-memory state on every save, so routing
/// external writes through the session is what keeps them from being
/// clobbered. All writes are serialized so concurrent requests can't
/// interleave read-modify-write cycles.
class AgentCaptionWriteService {
  AgentCaptionWriteService({MossConversionService? conversionService})
    : _conversionService = conversionService ?? MossConversionService();

  final Logger _logger = Logger('AgentCaptionWriteService');

  /// Stateless shared conversion implementation (exact source dimensions,
  /// structured diagnostics) — the same one the UI batch dialog uses.
  final MossConversionService _conversionService;

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

  // ---------------------------------------------------------------------------
  // Format conversion (Ideogram <-> MOSS), local and deterministic.
  // ---------------------------------------------------------------------------

  /// Converts structured captions in [category] through the live tab session.
  /// A null [filename] converts every convertible caption in the category;
  /// results land in [targetCategory] when given (created if missing),
  /// otherwise in place.
  Future<Response> convertViaSession(
    CaptionSessionService session, {
    String? filename,
    required String category,
    required String target,
    String? targetCategory,
    String? model,
  }) async {
    final ImageListState state = session.current.state;
    if (!state.categories.contains(category)) {
      return jsonResponse(400, <String, dynamic>{
        'error': 'unknown category "$category"',
        'categories': state.categories,
      });
    }

    final String destination = targetCategory ?? category;
    if (destination != category && !state.categories.contains(destination)) {
      session.addCategory(destination, format: 'json');
    }

    final List<AppImage> targets = <AppImage>[];
    final bool single = filename != null;
    if (single) {
      AppImage? match;
      for (final AppImage image in state.images) {
        if (p.basename(image.image.path) == filename) {
          match = image;
          break;
        }
      }
      if (match == null) {
        return jsonResponse(404, <String, dynamic>{
          'error':
              'image not loaded in the open tab — POST /api/folders/refresh '
              'first, then retry',
          'filename': filename,
        });
      }
      targets.add(match);
    } else {
      targets.addAll(state.images);
    }

    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    int converted = 0;
    int skipped = 0;
    for (final AppImage image in targets) {
      final String text = image.captions[category]?.text ?? '';
      final ({String? text, String? reason}) outcome = await _convertText(
        text,
        target: target,
        imageFile: image.image,
      );
      final Map<String, dynamic> entry = <String, dynamic>{
        'filename': p.basename(image.image.path),
      };
      if (outcome.text == null) {
        skipped++;
        entry['status'] = 'skipped';
        entry['reason'] = outcome.reason;
      } else {
        final AppImage updated = image.copyWith(
          captions: <String, CaptionEntry>{
            ...image.captions,
            destination: CaptionEntry(
              text: outcome.text!,
              model: model ?? _conversionModelTag(target),
              isEdited: true,
              timestamp: DateTime.now(),
            ),
          },
          lastModified: DateTime.now(),
        );
        await session.updateImage(image: updated);
        converted++;
        entry['status'] = 'converted';
        entry['category'] = destination;
        if (single) {
          entry['text'] = outcome.text;
        }
      }
      results.add(entry);
    }

    return jsonResponse(200, <String, dynamic>{
      'ok': true,
      'mode': 'live',
      'target': target,
      'converted': converted,
      'skipped': skipped,
      'results': results,
    });
  }

  /// Disk-path twin of [convertViaSession] for folders not open in a tab:
  /// direct read-modify-write of `db.json` under the serialized write lock.
  Future<Response> convertViaFile(
    String folder, {
    String? filename,
    required String category,
    required String target,
    String? targetCategory,
    String? model,
  }) async {
    final CaptionFileStore fileUtils = locator<CaptionFileStore>();
    final Either<Failure, CaptionDatabase> dbResult = await fileUtils.readDb(
      folder,
    );
    final CaptionDatabase? db = dbResult.getRight().toNullable();
    if (db == null) {
      final Failure f = dbResult.getLeft().toNullable()!;
      _logger.severe('POST /api/convert: db.json unreadable: $f');
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

    final String destination = targetCategory ?? category;
    if (destination != category && !db.categories.contains(destination)) {
      db.categories.add(destination);
      db.categoryFormats[destination] = 'json';
    }

    final List<CaptionData> targets = <CaptionData>[];
    final bool single = filename != null;
    if (single) {
      CaptionData? match;
      for (final CaptionData data in db.images) {
        if (data.filename == filename) {
          match = data;
          break;
        }
      }
      if (match == null) {
        return jsonResponse(404, <String, dynamic>{
          'error': 'image not found in db.json',
          'filename': filename,
        });
      }
      targets.add(match);
    } else {
      targets.addAll(db.images);
    }

    final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    int converted = 0;
    int skipped = 0;
    for (final CaptionData data in targets) {
      final String text = data.captions[category]?.text ?? '';
      final ({String? text, String? reason}) outcome = await _convertText(
        text,
        target: target,
        imageFile: File(p.join(folder, data.filename)),
      );
      final Map<String, dynamic> entry = <String, dynamic>{
        'filename': data.filename,
      };
      if (outcome.text == null) {
        skipped++;
        entry['status'] = 'skipped';
        entry['reason'] = outcome.reason;
      } else {
        final CaptionData updated = CaptionData(
          id: data.id,
          filename: data.filename,
          captions: <String, CaptionEntry>{
            ...data.captions,
            destination: CaptionEntry(
              text: outcome.text!,
              model: model ?? _conversionModelTag(target),
              isEdited: true,
              timestamp: DateTime.now(),
            ),
          },
          lastModified: DateTime.now(),
          tags: data.tags,
        );
        db.images[db.images.indexOf(data)] = updated;
        converted++;
        entry['status'] = 'converted';
        entry['category'] = destination;
        if (single) {
          entry['text'] = outcome.text;
        }
      }
      results.add(entry);
    }

    await fileUtils.writeDb(folder, db);
    return jsonResponse(200, <String, dynamic>{
      'ok': true,
      'mode': 'file',
      'target': target,
      'converted': converted,
      'skipped': skipped,
      'results': results,
    });
  }

  String _conversionModelTag(String target) =>
      target == 'moss' ? 'ideogram→moss' : 'moss→ideogram';

  /// Converts one caption string between formats through the shared
  /// [MossConversionService] (exact source dimensions, structured
  /// diagnostics). Returns `(text: null, reason: ...)` for anything that is
  /// not a caption in the source format, is already in the target format,
  /// or fails conversion.
  Future<({String? text, String? reason})> _convertText(
    String text, {
    required String target,
    required File imageFile,
  }) async {
    final MossConversionOutcome outcome = await _conversionService.convert(
      text: text,
      target: target == 'moss' ? CaptionFormat.moss : CaptionFormat.ideogram,
      imageFile: imageFile,
    );
    if (outcome.success) {
      return (text: outcome.text, reason: null);
    }
    final String reason =
        outcome.skippedReason ??
        outcome.diagnostics
            .map((MossFormatDiagnostic d) => d.message)
            .join('; ');
    if (outcome.fatal) {
      _logger.warning(
        'convert failed for ${p.basename(imageFile.path)}: $reason',
      );
    }
    return (text: null, reason: reason);
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
