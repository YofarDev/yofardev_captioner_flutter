import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/src/either.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/moss_format.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';
import 'package:yofardev_captioner/features/export/data/repositories/moss_training_exporter.dart';
import 'package:yofardev_captioner/features/export/domain/moss_training_models.dart';

/// Writes a real PNG of [width]×[height] (distinct corner pixels so any
/// axis swap shows up in decoded output) and returns its bytes.
Uint8List pngBytes(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  // asymmetric corner markers to expose transposition
  img.drawPixel(image, 0, 0, img.ColorRgb8(255, 0, 0));
  img.drawPixel(image, width - 1, height - 1, img.ColorRgb8(0, 255, 0));
  return Uint8List.fromList(img.encodePng(image));
}

AppImage imageWith(String name, Uint8List bytes, String caption) {
  final File file = File(
    '${Directory.systemTemp.createTempSync('moss_export_test').path}/$name',
  )..writeAsBytesSync(bytes);
  return AppImage(
    id: name,
    image: file,
    captions: <String, CaptionEntry>{'default': CaptionEntry(text: caption)},
  );
}

/// A 512×256 MOSS draft (used for mismatch fixtures).
const String draftExample =
    '{"width":512,"height":256, '
    '"bbox_coord_space":"abs", "bbox_format":"xyxy", '
    '"summary":{"caption":"a scene"}, '
    '"items":[{"label":"object","caption":"thing",'
    '"bbox":[10,20,110,120]}]}';

const String ideogramCaption =
    '{"high_level_description":"A man sits at a desk.","style_description": '
    '{"aesthetics":"","lighting":"","photo":"","medium":"photograph", '
    '"color_palette":[]},"compositional_deconstruction":{"background":"", '
    '"elements":[{"type":"obj","bbox":[0,0,1000,500],"desc":"left half"}]}}';

void main() {
  late MossTrainingExporter exporter;

  setUp(() {
    exporter = MossTrainingExporter();
  });

  group('MossTrainingExporter.buildPlan', () {
    test(
      '1864×1864 ideogram → 1024×1024 bucket with transformed boxes',
      () async {
        final AppImage image = imageWith(
          'a.png',
          pngBytes(1864, 1864),
          ideogramCaption,
        );
        final Either<Failure, MossTrainingExportPlan> result = await exporter
            .buildPlan(
              images: <AppImage>[image],
              category: 'default',
              options: const MossTrainingExportOptions(),
            );
        final MossTrainingExportPlan plan = result.getRight().toNullable()!;
        expect(plan.items, hasLength(1));
        final MossTrainingPrepItem item = plan.items.single;
        expect(item.sourceWidth, 1864);
        expect(item.transform.bucketWidth, 1024);
        expect(item.transform.bucketHeight, 1024);
        // ideogram [y1,x1,y2,x2]=[0,0,1000,500] → left half of the frame →
        // left half of the 1024² output (central crop is zero here).
        expect(item.boxes.single.outputBox, <int>[0, 0, 512, 1024]);
      },
    );

    test(
      'accepts MOSS drafts and direct Ideogram without an intermediate',
      () async {
        const MossLayoutCaption draft = MossLayoutCaption(
          width: 512,
          height: 256,
          summary: MossSummary(caption: 'a scene'),
          items: <MossItem>[
            MossItem(caption: 'thing', bbox: <int>[0, 0, 512, 256]),
          ],
        );
        final AppImage mossImage = imageWith(
          'moss.png',
          pngBytes(512, 256),
          draft.toJsonString(),
        );
        final AppImage plainImage = imageWith(
          'plain.png',
          pngBytes(100, 100),
          'just a plain caption',
        );
        final Either<Failure, MossTrainingExportPlan> result = await exporter
            .buildPlan(
              images: <AppImage>[mossImage, plainImage],
              category: 'default',
              options: const MossTrainingExportOptions(),
            );
        final MossTrainingExportPlan plan = result.getRight().toNullable()!;
        expect(plan.items, hasLength(1));
        expect(plan.items.single.transform.bucketWidth, 512);
        expect(plan.items.single.transform.bucketHeight, 256);
        expect(plan.skipped.single.fileName, 'plain.png');
      },
    );

    test(
      'mismatched draft frames are SKIPPED by default (no silent rescale)',
      () async {
        // Codex review finding 4: arbitrary mismatches (imported layout /
        // changed image) were silently rescaled. Default must skip, with the
        // original declared dimensions in the reason.
        final AppImage image = imageWith(
          'changed.png',
          pngBytes(300, 200),
          // Declares 512×256 but the real image is 300×200 — non-legacy.
          draftExample,
        );
        final Either<Failure, MossTrainingExportPlan> result = await exporter
            .buildPlan(
              images: <AppImage>[image],
              category: 'default',
              options: const MossTrainingExportOptions(),
            );
        final MossTrainingExportPlan plan = result.getRight().toNullable()!;
        expect(plan.items, isEmpty);
        expect(plan.skipped.single.fileName, 'changed.png');
        expect(plan.skipped.single.reason, contains('512x256'));
        expect(plan.skipped.single.reason, contains('300x200'));
      },
    );

    test(
      'mismatched drafts rescale only with the explicit reconciliation choice',
      () async {
        final AppImage image = imageWith(
          'changed.png',
          pngBytes(300, 200),
          draftExample,
        );
        final Either<Failure, MossTrainingExportPlan> result = await exporter
            .buildPlan(
              images: <AppImage>[image],
              category: 'default',
              options: const MossTrainingExportOptions(
                allowFrameReconciliation: true,
              ),
            );
        final MossTrainingExportPlan plan = result.getRight().toNullable()!;
        expect(plan.items, hasLength(1));
        expect(plan.items.single.warnings.join(' '), contains('512x256'));
        expect(plan.items.single.warnings.join(' '), contains('300x200'));
        // Boxes were rescaled into the real frame and stay within it.
        final List<int> out = plan.items.single.boxes.single.outputBox!;
        expect(out[0], lessThanOrEqualTo(out[2]));
        expect(out[2], lessThanOrEqualTo(300));
        expect(out[3], lessThanOrEqualTo(200));
      },
    );

    test('native prompts are refused (already compiled)', () async {
      const String nativePrompt =
          '{"bbox_coord_space":"abs_centralized","bbox_format":"yxyx",'
          '"summary":{"caption":"x"},'
          '"items":[{"label":"object","caption":"c","bbox":[0,0,10,10]}]}';
      final AppImage image = imageWith('n.png', pngBytes(64, 64), nativePrompt);
      final Either<Failure, MossTrainingExportPlan> result = await exporter
          .buildPlan(
            images: <AppImage>[image],
            category: 'default',
            options: const MossTrainingExportOptions(),
          );
      final MossTrainingExportPlan plan = result.getRight().toNullable()!;
      expect(plan.items, isEmpty);
      expect(plan.skipped.single.reason, contains('native'));
    });

    test('partial clipping is diagnosed: cropped edge flagged, interior clean, '
        'fully-cropped boxes dropped (Codex rev-2 finding 3)', () async {
      // 1000×2000 at resolution 1024 → bucket 720×1456, scale-to
      // 728×1456, central crop x=4: the full-width box IS cut, an
      // interior box is not, and a box inside the cropped strip is
      // dropped.
      const String caption =
          '{"high_level_description":"tall", "style_description": '
          '{"aesthetics":"", "lighting":"", "photo":"", '
          '"medium":"photograph", "color_palette":[]}, '
          '"compositional_deconstruction": {"background":"", "elements": '
          '[{"type":"obj", "bbox":[0,0,1000,2000], "desc":"full frame"}, '
          '{"type":"obj", "bbox":[300,600,500,800], "desc":"interior"}, '
          '{"type":"obj", "bbox":[0,0,1000,5], "desc":"left strip"}]}}';
      final AppImage image = imageWith(
        'tall.png',
        pngBytes(1000, 2000),
        caption,
      );
      final Either<Failure, MossTrainingExportPlan> result = await exporter
          .buildPlan(
            images: <AppImage>[image],
            category: 'default',
            options: const MossTrainingExportOptions(),
          );
      final MossTrainingExportPlan plan = result.getRight().toNullable()!;
      expect(plan.items, hasLength(1));
      final MossTrainingPrepItem item = plan.items.single;
      expect(item.transform.cropX, 4);
      final String warnings = item.warnings.join('\n');
      // Full-frame box: partially clipped and flagged with coordinates.
      expect(warnings, contains('full frame'));
      expect(warnings, contains('partially clipped'));
      // Interior box: no clip warning for it.
      final List<String> interiorWarnings = item.warnings
          .where((String w) => w.contains('interior') && w.contains('clip'))
          .toList();
      expect(interiorWarnings, isEmpty);
      // Left-strip box: fully cropped away → dropped, not partially.
      expect(item.droppedBoxCount, 1);
      expect(warnings, contains('left strip'));
      expect(item.boxes, hasLength(2));
    });

    test('invalid options are rejected at the repository boundary', () async {
      final AppImage image = imageWith(
        'ok.png',
        pngBytes(64, 64),
        ideogramCaption,
      );
      final Either<Failure, MossTrainingExportPlan> result = await exporter
          .buildPlan(
            images: <AppImage>[image],
            category: 'default',
            options: const MossTrainingExportOptions(resolution: 0),
          );
      expect(result.getLeft().toNullable(), isNotNull);
    });

    test(
      'rejects basename collisions instead of silently overwriting',
      () async {
        final AppImage a = imageWith(
          'same.png',
          pngBytes(64, 64),
          ideogramCaption,
        );
        final AppImage b = imageWith(
          'same.png',
          pngBytes(64, 64),
          ideogramCaption,
        );
        final Either<Failure, MossTrainingExportPlan> result = await exporter
            .buildPlan(
              images: <AppImage>[a, b],
              category: 'default',
              options: const MossTrainingExportOptions(),
            );
        expect(result.getLeft().toNullable(), isNotNull);
      },
    );
  });

  group('MossTrainingExporter.exportPlan', () {
    test(
      'produces a valid zip: real pixels, native captions, root manifest',
      () async {
        final AppImage image = imageWith(
          'sample.png',
          pngBytes(1864, 1864),
          ideogramCaption,
        );
        final MossTrainingExportPlan plan = (await exporter.buildPlan(
          images: <AppImage>[image],
          category: 'default',
          options: const MossTrainingExportOptions(),
        )).getRight().toNullable()!;
        final (MossTrainingExportResult result, Uint8List zipBytes) =
            (await exporter.exportPlan(plan: plan)).getRight().toNullable()!;

        expect(result.imageCount, 1);
        expect(result.outputHashes, contains('images/sample.png'));

        // Unpack the real archive.
        final Archive archive = ZipDecoder().decodeBytes(zipBytes);
        final List<String> names =
            archive.files.map((ArchiveFile f) => f.name).toList()..sort();
        expect(names, <String>[
          'images/sample.json',
          'images/sample.png',
          'manifest.json',
        ]);

        // Decoded output pixels match the frame the caption was compiled
        // against.
        final Uint8List pngBytesRaw = Uint8List.fromList(
          archive.files
                  .firstWhere((ArchiveFile f) => f.name == 'images/sample.png')
                  .content
              as List<int>,
        );
        final img.Image decoded = img.decodePng(pngBytesRaw)!;
        expect(decoded.width, 1024);
        expect(decoded.height, 1024);

        // Caption is a native centered prompt whose boxes invert to the same
        // frame.
        final String captionJson = utf8.decode(
          archive.files
                  .firstWhere((ArchiveFile f) => f.name == 'images/sample.json')
                  .content
              as List<int>,
        );
        final ({
          MossLayoutCaption? caption,
          List<MossFormatDiagnostic> diagnostics,
        })
        parsedNative = parseMossNative(
          captionJson,
          canvasWidth: 1024,
          canvasHeight: 1024,
        );
        expect(parsedNative.diagnostics, isEmpty);
        expect(parsedNative.caption!.width, 1024);
        expect(parsedNative.caption!.height, 1024);
        final List<int> box = parsedNative.caption!.items.single.bbox!;
        // parseMossNative inverted the centered sidecar back to top-left
        // xyxy — proving the sidecar was emitted in the native centered
        // frame against the 1024² output pixels.
        expect(box, <int>[0, 0, 512, 1024]);

        // The hash key matches the archive entry name.
        expect(result.outputHashes['images/sample.png'], isNotNull);

        final Map<String, dynamic> manifest =
            jsonDecode(
                  utf8.decode(
                    archive.files
                            .firstWhere(
                              (ArchiveFile f) => f.name == 'manifest.json',
                            )
                            .content
                        as List<int>,
                  ),
                )
                as Map<String, dynamic>;
        expect(manifest['profile_version'], kMossTrainingProfileVersion);
        final Map<String, dynamic> manifestImages =
            manifest['images'] as Map<String, dynamic>;
        final Map<String, dynamic> sampleEntry =
            manifestImages['sample.png'] as Map<String, dynamic>;
        expect(sampleEntry['output_sha256'], isNotEmpty);
        // manifest lives outside images/
        expect(manifest.containsKey('suggested_loader_settings'), isTrue);
        // Codex review finding 12: loader settings must use the verified
        // 'json' spelling and the identity/JSON-integrity settings.
        final Map<String, dynamic> loader =
            manifest['suggested_loader_settings'] as Map<String, dynamic>;
        expect(loader['caption_ext'], 'json');
        expect(loader['scale'], 1.0);
        expect(loader['random_scale'], false);
        expect(loader['shuffle_tokens'], false);
        expect(loader['token_dropout_rate'], 0.0);
        expect(loader['caption_dropout_rate'], 0.0);
        expect(loader['flip'], false);
        expect(loader['bucket_tolerance'], 16);
        // Per-axis realized scales are recorded (finding 6 evidence).
        final Map<String, dynamic> itemManifest =
            (manifest['images'] as Map<String, dynamic>)['sample.png']
                as Map<String, dynamic>;
        final Map<String, dynamic> transform =
            itemManifest['transform'] as Map<String, dynamic>;
        expect(transform['scale_factor_x'], isA<num>());
        expect(transform['scale_factor_y'], isA<num>());
      },
    );

    test(
      'fixed point: feeding the prepared dims back yields identity',
      () async {
        // 23.png scenario with a portrait variant for asymmetry.
        final AppImage portrait = imageWith(
          'p.png',
          pngBytes(832, 1216),
          ideogramCaption,
        );
        final MossTrainingExportPlan plan = (await exporter.buildPlan(
          images: <AppImage>[portrait],
          category: 'default',
          options: const MossTrainingExportOptions(),
        )).getRight().toNullable()!;
        final (MossTrainingExportResult result, _) = (await exporter.exportPlan(
          plan: plan,
        )).getRight().toNullable()!;
        expect(result.imageCount, 1);
        final MossTrainingPrepItem item = plan.items.single;
        // A loader pass with bucket_tolerance 16 on the prepared frame is a
        // no-op (verified exhaustively in moss_bucketing_test).
        expect(item.transform.bucketWidth % 16, 0);
        expect(item.transform.bucketHeight % 16, 0);
      },
    );
  });
}
