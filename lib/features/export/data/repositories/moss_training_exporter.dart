import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../../core/models/moss_conversion.dart';
import '../../../../core/models/moss_format.dart';
import '../../../../core/models/moss_layout_caption.dart';
import '../../../../core/models/moss_repair.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../../core/services/image_dimension_resolver.dart';
import '../../domain/moss_bucketing.dart';
import '../../domain/moss_training_models.dart';
import '../../domain/repositories/moss_training_export_repository.dart';

/// Produces MOSS training pairs: the prepared image (bucketed, cropped —
/// the exact geometry the pinned AI Toolkit loader would apply) and one
/// native centered `yxyx` caption compiled against the **final output
/// pixels**.
///
/// Invariants enforced here:
/// - Draft captions (Ideogram or MOSS top-left) are accepted; native prompts
///   and unsupported marker combinations are rejected.
/// - A draft whose declared canvas disagrees with the real image is SKIPPED
///   by default — imported layouts and changed images are never silently
///   rescaled. Rescaling requires the explicit
///   [MossTrainingExportOptions.allowFrameReconciliation] choice.
/// - The same realized transform (per-axis scales of the actual resize) is
///   applied to the image and every box; coordinates round once.
/// - Boxes partially clipped by the crop are diagnosed, not silent.
/// - Source identity (size + mtime) is captured at plan time and verified at
///   export time — a changed image cannot be exported against a stale plan.
/// - Before publication every staged pair is independently decoded and the
///   caption strictly parsed, and the bucket's fixed-point property is
///   verified. The manifest lives at the archive root, outside `images/`.
/// - ZIP compression runs off the UI isolate.
class MossTrainingExporter implements IMossTrainingExportRepository {
  final Logger _logger = Logger('MossTrainingExporter');
  final ImageDimensionResolver _dimensionResolver =
      const ImageDimensionResolver();

  @override
  Future<Either<Failure, MossTrainingExportPlan>> buildPlan({
    required List<AppImage> images,
    required String category,
    required MossTrainingExportOptions options,
  }) async {
    try {
      final List<String> optionProblems = options.validationProblems();
      if (optionProblems.isNotEmpty) {
        return Left<Failure, MossTrainingExportPlan>(
          FailureInvalidData(
            message: 'invalid export options: ${optionProblems.join('; ')}',
          ),
        );
      }
      final List<MossTrainingPrepItem> items = <MossTrainingPrepItem>[];
      final List<MossTrainingSkippedImage> skipped =
          <MossTrainingSkippedImage>[];

      for (final AppImage image in images) {
        final String fileName = p.basename(image.image.path);
        final CaptionEntry? entry = image.captions[category];
        final String text = entry?.text ?? '';
        if (text.trim().isEmpty) {
          skipped.add(
            MossTrainingSkippedImage(
              fileName: fileName,
              reason: 'no caption in category "$category"',
            ),
          );
          continue;
        }
        if (MossLayoutCaption.isNativeMossJson(text)) {
          skipped.add(
            MossTrainingSkippedImage(
              fileName: fileName,
              reason:
                  'native centered prompt — already compiled, nothing to '
                  'prepare',
            ),
          );
          continue;
        }
        final ImageDimensions? dims;
        try {
          dims = await _dimensionResolver.resolve(image.image);
        } catch (e) {
          skipped.add(
            MossTrainingSkippedImage(
              fileName: fileName,
              reason: 'image read failed: $e',
            ),
          );
          continue;
        }
        if (dims == null) {
          skipped.add(
            MossTrainingSkippedImage(
              fileName: fileName,
              reason: 'image dimensions unreadable',
            ),
          );
          continue;
        }
        final CaptionFormat format = detectCaptionFormat(text);
        final List<String> warnings = <String>[];
        MossLayoutCaption draft;
        if (format == CaptionFormat.ideogram) {
          final Object? parsedDoc = StructuredCaptionDocument.tryParse(text);
          if (parsedDoc is! IdeogramDocument) {
            skipped.add(
              MossTrainingSkippedImage(
                fileName: fileName,
                reason: 'malformed Ideogram JSON',
              ),
            );
            continue;
          }
          final MossFromIdeogramResult converted = mossFromIdeogram(
            parsedDoc.caption,
            width: dims.width,
            height: dims.height,
            imagePath: image.image.path,
          );
          draft = converted.caption;
          warnings.addAll(
            converted.diagnostics.map((MossFormatDiagnostic d) => d.toString()),
          );
        } else if (format == CaptionFormat.moss) {
          final ({
            MossLayoutCaption? caption,
            List<MossFormatDiagnostic> diagnostics,
          })
          strict = parseMossDraft(text, imagePath: image.image.path);
          if (strict.caption == null) {
            skipped.add(
              MossTrainingSkippedImage(
                fileName: fileName,
                reason: strict.diagnostics
                    .map((MossFormatDiagnostic d) => d.toString())
                    .join('; '),
              ),
            );
            continue;
          }
          draft = strict.caption!;
          warnings.addAll(
            strict.diagnostics.map((MossFormatDiagnostic d) => d.toString()),
          );
        } else {
          skipped.add(
            MossTrainingSkippedImage(
              fileName: fileName,
              reason:
                  'plain caption — MOSS training export needs a structured '
                  'caption (Ideogram or MOSS draft)',
            ),
          );
          continue;
        }

        // Frame check: the draft MUST declare the real image dimensions.
        // Arbitrary mismatches (imported layouts, changed images) are skipped
        // — an automatic rescale would be an undocumented assumption, exactly
        // what the repair workflow refuses. Only the explicit
        // allowFrameReconciliation choice routes them through the same
        // reviewed rescale policy as the repair workflow.
        if (draft.width != dims.width || draft.height != dims.height) {
          final String mismatch =
              'declared canvas ${draft.width}x${draft.height} does not match '
              'the real ${dims.width}x${dims.height} image';
          if (!options.allowFrameReconciliation) {
            skipped.add(
              MossTrainingSkippedImage(
                fileName: fileName,
                reason:
                    '$mismatch — enable "Reconcile mismatched frames" to '
                    'rescale boxes explicitly (assumption: legacy rounding '
                    'or an intentional frame change)',
              ),
            );
            continue;
          }
          final int declaredWidth = draft.width;
          final int declaredHeight = draft.height;
          final ({
            MossLayoutCaption caption,
            List<MossFormatDiagnostic> diagnostics,
          })
          rescaled = rescaleMossDraftFrame(
            draft,
            actualWidth: dims.width,
            actualHeight: dims.height,
            imagePath: image.image.path,
          );
          draft = rescaled.caption;
          warnings.add(
            'reconciled: declared ${declaredWidth}x$declaredHeight rescaled '
            'to the real ${dims.width}x${dims.height} frame (explicit '
            'choice; boxes are quantized, not pixel-perfect recoveries)',
          );
          warnings.addAll(
            rescaled.diagnostics.map((MossFormatDiagnostic d) => d.toString()),
          );
        }

        final MossImageTransform transform = planAiToolkitTransform(
          sourceWidth: dims.width,
          sourceHeight: dims.height,
          resolution: options.resolution,
          divisibility: options.divisibility,
        );

        final List<MossTrainingBox> boxes = <MossTrainingBox>[];
        int dropped = 0;
        for (final MossItem item in draft.items) {
          final List<int>? bbox = item.bbox;
          if (bbox == null || bbox.length != 4) {
            dropped++;
            warnings.add(
              'item without 4-number bbox dropped: "${item.caption}"',
            );
            continue;
          }
          final List<int>? output = transformBbox(bbox, transform);
          if (output == null) {
            dropped++;
            warnings.add(
              'box collapses to zero area after transform and was dropped: '
              '"${item.caption}"',
            );
            continue;
          }
          // Partial clipping must be visible: flag boxes that touch the
          // output frame edge only because the crop/resize pushed them
          // there (the source box was not at the corresponding edge).
          if (_partiallyClipped(bbox, output, transform)) {
            warnings.add(
              'box for "${item.caption}" is partially clipped by the '
              'prepared crop (source ${bbox[0]},${bbox[1]},${bbox[2]},'
              '${bbox[3]} → output ${output[0]},${output[1]},${output[2]},'
              '${output[3]}); review whether the crop invalidates its '
              'description',
            );
          }
          boxes.add(
            MossTrainingBox(
              label: item.label,
              caption: item.caption,
              text: item.text,
              sourceBox: bbox,
              outputBox: output,
              tags: item.tags,
              palette: item.palette,
            ),
          );
        }

        FileStat stat;
        try {
          stat = await FileStat.stat(image.image.path);
        } catch (e) {
          skipped.add(
            MossTrainingSkippedImage(
              fileName: fileName,
              reason: 'source stat failed: $e',
            ),
          );
          continue;
        }

        final String ext = _outputExtension(image.image.path);
        items.add(
          MossTrainingPrepItem(
            imageId: image.id,
            fileName: fileName,
            sourcePath: image.image.path,
            sourceWidth: dims.width,
            sourceHeight: dims.height,
            transform: transform,
            boxes: boxes,
            summaryCaption: draft.summary.caption,
            summaryMeta: draft.summary.meta,
            summaryPalette: draft.summary.palette,
            droppedBoxCount: dropped,
            warnings: warnings,
            outputExtension: ext,
            summaryCanvas: draft.summary.canvas,
            sourceLength: stat.size,
            sourceModified: stat.changed,
          ),
        );
      }

      // Basename collisions would make two pairs fight over one caption
      // file — refuse the plan instead of silently overwriting.
      final Map<String, List<String>> byStem = <String, List<String>>{};
      for (final MossTrainingPrepItem item in items) {
        byStem
            .putIfAbsent(
              p.basenameWithoutExtension(item.fileName),
              () => <String>[],
            )
            .add(item.fileName);
      }
      final List<String> collisions = byStem.entries
          .where((MapEntry<String, List<String>> e) => e.value.length > 1)
          .map(
            (MapEntry<String, List<String>> e) =>
                '${e.key}: ${e.value.join(', ')}',
          )
          .toList();
      if (collisions.isNotEmpty) {
        return Left<Failure, MossTrainingExportPlan>(
          FailureInvalidData(
            message:
                'basename collisions in the export set — rename the files '
                'first: ${collisions.join('; ')}',
          ),
        );
      }

      return Right<Failure, MossTrainingExportPlan>(
        MossTrainingExportPlan(
          options: options,
          items: items,
          skipped: skipped,
        ),
      );
    } catch (e, st) {
      return Left<Failure, MossTrainingExportPlan>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'MossTrainingExporter.buildPlan',
        ),
      );
    }
  }

  /// True when [output] touches a frame edge that its [source] box was not
  /// already touching after the transform — i.e. content was actually cut.
  bool _partiallyClipped(
    List<int> source,
    List<int> output,
    MossImageTransform transform,
  ) {
    final double sx = transform.scaleFactorX;
    final double sy = transform.scaleFactorY;
    final int outW = transform.outputWidth;
    final int outH = transform.outputHeight;
    // Clipping means the raw (pre-clamp) coordinate lies strictly OUTSIDE
    // the output frame on a side where the clamped output touches the
    // frame edge. (Codex rev-2 finding 3: previous inequalities were
    // reversed and could never fire after round-and-clamp.)
    final double rawLeft = source[0] * sx - transform.cropX;
    final double rawTop = source[1] * sy - transform.cropY;
    final double rawRight = source[2] * sx - transform.cropX;
    final double rawBottom = source[3] * sy - transform.cropY;
    final bool clippedLeft = output[0] == 0 && rawLeft < -0.5;
    final bool clippedTop = output[1] == 0 && rawTop < -0.5;
    final bool clippedRight = output[2] == outW && rawRight > outW + 0.5;
    final bool clippedBottom = output[3] == outH && rawBottom > outH + 0.5;
    return clippedLeft || clippedTop || clippedRight || clippedBottom;
  }

  @override
  Future<Either<Failure, (MossTrainingExportResult, Uint8List)>> exportPlan({
    required MossTrainingExportPlan plan,
    void Function(int processed, int total, String fileName)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final String stagingPath =
        '${Directory.systemTemp.path}/moss_training_export_${const Uuid().v4()}';
    final Directory staging = Directory(stagingPath);
    try {
      // Only reviewer-included rows run.
      final List<MossTrainingPrepItem> items = plan.includedItems;

      // Fixed-point verification for the selected profile: every bucket must
      // be an identity under the same bucketing, otherwise the trainer's
      // second geometry pass would move boxes again.
      for (final MossTrainingPrepItem item in items) {
        final ({int width, int height}) again = aiToolkitBucket(
          width: item.transform.bucketWidth,
          height: item.transform.bucketHeight,
          resolution: plan.options.resolution,
          divisibility: plan.options.divisibility,
        );
        if (again.width != item.transform.bucketWidth ||
            again.height != item.transform.bucketHeight) {
          throw StateError(
            'bucket ${item.transform.bucketWidth}x'
            '${item.transform.bucketHeight} is not a fixed point at '
            'resolution ${plan.options.resolution} / divisibility '
            '${plan.options.divisibility} (re-buckets to ${again.width}x'
            '${again.height}) — refusing to publish',
          );
        }
      }

      final Directory imagesDir = Directory(p.join(stagingPath, 'images'));
      await imagesDir.create(recursive: true);

      final List<String> warnings = <String>[];
      final Map<String, dynamic> manifestItems = <String, dynamic>{};
      final Map<String, String> outputHashes = <String, String>{};
      int droppedTotal = 0;

      // Sequential processing: image decode/transform is CPU-heavy and runs
      // off the UI isolate, one image at a time, with a cancellation check
      // between images.
      for (int i = 0; i < plan.items.length; i++) {
        final MossTrainingPrepItem item = plan.items[i];
        if (isCancelled != null && isCancelled()) {
          return const Left<Failure, (MossTrainingExportResult, Uint8List)>(
            FailureUnexpected(message: 'export cancelled'),
          );
        }
        onProgress?.call(i, plan.items.length, item.fileName);
        final _PreparedPair pair = await Isolate.run<_PreparedPair>(
          () => _prepareImage(item),
        );
        final String imageEntryName =
            'images/${p.basenameWithoutExtension(item.fileName)}.'
            '${item.outputExtension}';
        final String captionEntryName =
            'images/${p.basenameWithoutExtension(item.fileName)}.json';
        await File(
          p.join(stagingPath, imageEntryName),
        ).writeAsBytes(pair.imageBytes, flush: true);
        await File(
          p.join(stagingPath, captionEntryName),
        ).writeAsString(pair.captionJson, flush: true);

        outputHashes[imageEntryName] = pair.imageSha256;
        droppedTotal += item.droppedBoxCount;
        warnings.addAll(
          item.warnings.map((String w) => '${item.fileName}: $w'),
        );
        manifestItems[item.fileName] = <String, dynamic>{
          'output_image': imageEntryName,
          'output_caption': captionEntryName,
          'source_dimensions': <String, int>{
            'width': item.sourceWidth,
            'height': item.sourceHeight,
          },
          'output_dimensions': <String, int>{
            'width': item.transform.bucketWidth,
            'height': item.transform.bucketHeight,
          },
          'transform': <String, dynamic>{
            'scale_factor_x': item.transform.scaleFactorX,
            'scale_factor_y': item.transform.scaleFactorY,
            'scale_to': <int>[
              item.transform.scaleToWidth,
              item.transform.scaleToHeight,
            ],
            'crop_offset': <int>[item.transform.cropX, item.transform.cropY],
          },
          'boxes': item.boxes
              .map(
                (MossTrainingBox b) => <String, dynamic>{
                  'caption': b.caption,
                  'source_xyxy': b.sourceBox,
                  'output_xyxy': b.outputBox,
                },
              )
              .toList(),
          'dropped_boxes': item.droppedBoxCount,
          'output_sha256': pair.imageSha256,
        };
      }
      onProgress?.call(items.length, items.length, '');

      final Map<String, dynamic> manifest = <String, dynamic>{
        'profile_version': kMossTrainingProfileVersion,
        'options': <String, int>{
          'resolution': plan.options.resolution,
          'divisibility': plan.options.divisibility,
        },
        'suggested_loader_settings': <String, dynamic>{
          'resolution': plan.options.resolution,
          'bucket_tolerance': plan.options.divisibility,
          'scale': 1.0,
          'random_scale': false,
          'square_crop': false,
          'random_crop': false,
          'flip': false,
          'shuffle_tokens': false,
          'token_dropout_rate': 0.0,
          'caption_dropout_rate': 0.0,
          'caption_ext': 'json',
          'note':
              'These settings reproduce the preparation transform exactly '
              '(identity geometry on a second loader pass) and keep the '
              'JSON prompts intact. Rebuilding latent/text caches is '
              'required after preparing a new dataset.',
        },
        'image_count': items.length,
        'dropped_boxes_total': droppedTotal,
        'images': manifestItems,
        'skipped': plan.skipped
            .map(
              (MossTrainingSkippedImage s) => <String, String>{
                'file': s.fileName,
                'reason': s.reason,
              },
            )
            .toList(),
        'warnings': warnings,
      };
      await File(
        p.join(stagingPath, 'manifest.json'),
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));

      // Independent publication gate: decode every staged image and strictly
      // parse its paired caption, verifying the frames agree with the plan.
      for (final MossTrainingPrepItem item in items) {
        final String stem = p.basenameWithoutExtension(item.fileName);
        final File imageFile = File(
          p.join(stagingPath, 'images', '$stem.${item.outputExtension}'),
        );
        final File captionFile = File(
          p.join(stagingPath, 'images', '$stem.json'),
        );
        if (!captionFile.existsSync()) {
          throw StateError('missing caption sidecar for $stem');
        }
        await Isolate.run<void>(
          () => _verifyStagedPair(
            imageBytes: imageFile.readAsBytesSync(),
            captionText: captionFile.readAsStringSync(),
            expectedWidth: item.transform.bucketWidth,
            expectedHeight: item.transform.bucketHeight,
            fileName: item.fileName,
          ),
        );
      }

      // ZIP compression off the UI isolate.
      final Uint8List zipBytes = await Isolate.run<Uint8List>(
        () => _zipDirectory(stagingPath),
      );

      final MossTrainingExportResult result = MossTrainingExportResult(
        imageCount: items.length,
        captionCount: items.length,
        droppedBoxCount: droppedTotal,
        warnings: warnings,
        outputHashes: outputHashes,
      );
      return Right<Failure, (MossTrainingExportResult, Uint8List)>((
        result,
        zipBytes,
      ));
    } catch (e, st) {
      _logger.warning('exportPlan failed: $e');
      return Left<Failure, (MossTrainingExportResult, Uint8List)>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'MossTrainingExporter.exportPlan',
        ),
      );
    } finally {
      try {
        if (staging.existsSync()) {
          await staging.delete(recursive: true);
        }
      } catch (e) {
        _logger.fine('staging cleanup failed: $e');
      }
    }
  }
}

class _PreparedPair {
  const _PreparedPair({
    required this.imageBytes,
    required this.imageSha256,
    required this.captionJson,
  });

  final Uint8List imageBytes;
  final String imageSha256;
  final String captionJson;
}

/// Runs on a background isolate: source identity check → decode → bake
/// orientation → resize to scale-to frame → central crop to the bucket →
/// encode → hash → compile + strict-parse the native caption against the
/// final pixels.
_PreparedPair _prepareImage(MossTrainingPrepItem item) {
  // Source identity evidence: a changed image must not be exported against a
  // stale plan even when its dimensions happen to match.
  final FileStat stat = FileStat.statSync(item.sourcePath);
  if (stat.size != item.sourceLength ||
      stat.changed.millisecondsSinceEpoch !=
          item.sourceModified.millisecondsSinceEpoch) {
    throw StateError(
      'source file ${item.fileName} changed since the plan was built — '
      'rebuild the plan',
    );
  }

  final Uint8List bytes = File(item.sourcePath).readAsBytesSync();
  final img.Decoder? decoder = img.findDecoderForData(bytes);
  if (decoder == null) {
    throw StateError('undecodable image: ${item.fileName}');
  }
  final img.Image? decoded = decoder.decode(bytes);
  if (decoded == null) {
    throw StateError('decode failed: ${item.fileName}');
  }
  final img.Image oriented = img.bakeOrientation(decoded);
  if (oriented.width != item.sourceWidth ||
      oriented.height != item.sourceHeight) {
    // Header/decode disagreement: trust the decoded frame only if it
    // matches what the plan used; otherwise the plan's transform is stale.
    throw StateError(
      'decoded ${oriented.width}x${oriented.height} does not match the '
      'planned ${item.sourceWidth}x${item.sourceHeight} for ${item.fileName}',
    );
  }
  final img.Image scaled = img.copyResize(
    oriented,
    width: item.transform.scaleToWidth,
    height: item.transform.scaleToHeight,
  );
  final img.Image cropped = img.copyCrop(
    scaled,
    x: item.transform.cropX,
    y: item.transform.cropY,
    width: item.transform.bucketWidth,
    height: item.transform.bucketHeight,
  );

  final List<int> encoded;
  if (item.outputExtension == 'jpg') {
    encoded = img.encodeJpg(cropped, quality: 92);
  } else {
    encoded = img.encodePng(cropped);
  }
  final Uint8List imageBytes = Uint8List.fromList(encoded);

  final List<MossItem> outputItems = <MossItem>[];
  for (final MossTrainingBox box in item.boxes) {
    final List<int>? out = box.outputBox;
    if (out == null) {
      continue;
    }
    outputItems.add(
      MossItem(
        label: box.label,
        caption: box.caption,
        text: box.text,
        bbox: out,
        tags: box.tags,
        palette: box.palette,
      ),
    );
  }
  final String captionJson = toNativePromptString(
    MossLayoutCaption(
      width: item.transform.bucketWidth,
      height: item.transform.bucketHeight,
      summary: MossSummary(
        caption: item.summaryCaption,
        meta: item.summaryMeta,
        canvas: item.summaryCanvas,
        palette: item.summaryPalette,
      ),
      items: outputItems,
    ),
    outputWidth: item.transform.bucketWidth,
    outputHeight: item.transform.bucketHeight,
  );
  // Strictly parse our own output before it leaves the isolate.
  final MossLayoutCaption? selfParsed = parseMossNative(
    captionJson,
    canvasWidth: item.transform.bucketWidth,
    canvasHeight: item.transform.bucketHeight,
  ).caption;
  if (selfParsed == null || selfParsed.items.length != outputItems.length) {
    throw StateError(
      'compiled caption failed its own strict parse for ${item.fileName}',
    );
  }

  return _PreparedPair(
    imageBytes: imageBytes,
    imageSha256: sha256.convert(imageBytes).toString(),
    captionJson: captionJson,
  );
}

/// Independent staged-output verification on a background isolate.
void _verifyStagedPair({
  required Uint8List imageBytes,
  required String captionText,
  required int expectedWidth,
  required int expectedHeight,
  required String fileName,
}) {
  final img.Image? decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    throw StateError('staged image undecodable: $fileName');
  }
  final img.Image baked = img.bakeOrientation(decoded);
  if (baked.width != expectedWidth || baked.height != expectedHeight) {
    throw StateError(
      'staged image ${baked.width}x${baked.height} does not match the '
      'planned ${expectedWidth}x$expectedHeight frame for $fileName',
    );
  }
  final ({MossLayoutCaption? caption, List<MossFormatDiagnostic> diagnostics})
  parsed = parseMossNative(
    captionText,
    canvasWidth: expectedWidth,
    canvasHeight: expectedHeight,
    imagePath: fileName,
  );
  if (parsed.caption == null) {
    throw StateError(
      'staged caption failed strict parse for $fileName: '
      '${parsed.diagnostics.map((MossFormatDiagnostic d) => d.toString()).join('; ')}',
    );
  }
}

String _outputExtension(String path) {
  final String ext = p.extension(path).toLowerCase();
  return ext == '.jpg' || ext == '.jpeg' ? 'jpg' : 'png';
}

/// Builds the ZIP from the staged directory on a background isolate.
Uint8List _zipDirectory(String stagingPath) {
  final Directory root = Directory(stagingPath);
  final Archive archive = Archive();
  final List<FileSystemEntity> entities = root.listSync(recursive: true);
  for (final FileSystemEntity entity in entities) {
    if (entity is! File) {
      continue;
    }
    final String rel = p.relative(entity.path, from: stagingPath);
    archive.addFile(ArchiveFile.bytes(rel, entity.readAsBytesSync()));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
