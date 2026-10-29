import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:image/image.dart' as img;
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/moss_format.dart';
import 'package:yofardev_captioner/core/models/moss_repair.dart';
import 'package:yofardev_captioner/core/services/image_dimension_resolver.dart';
import 'package:yofardev_captioner/core/services/moss_conversion_service.dart';
import 'package:yofardev_captioner/features/caption_session/caption_session.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/legacy_moss_repair/legacy_moss_repair_cubit.dart';
import 'package:yofardev_captioner/features/captioning/presentation/bloc/legacy_moss_repair/legacy_moss_repair_state.dart';

Uint8List pngBytes(int width, int height) {
  final img.Image image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(5, 5, 5));
  return Uint8List.fromList(img.encodePng(image));
}

AppImage makeImage(String id, File file, Map<String, CaptionEntry> captions) =>
    AppImage(id: id, image: file, captions: captions);

void main() {
  // Codex review finding 3: repair reconversion converted the MOSS caption
  // (already the target format → always skipped). These tests pin the fixed
  // behavior: reconversion uses the captured Ideogram source, categories are
  // bound at audit time, and both sources are change-guarded.
  group('RepairLegacyMossCubit', () {
    late Directory tempDir;
    late _RecordingSession session;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('moss_repair_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File png(String name) {
      final File f = File('${tempDir.path}/$name');
      f.writeAsBytesSync(pngBytes(1864, 1864));
      return f;
    }

    const String ideogramText =
        '{"high_level_description":"a scene", "style_description": '
        '{"aesthetics":"", "lighting":"", "photo":"", '
        '"medium":"photograph", "color_palette":[]}, '
        '"compositional_deconstruction": {"background":"", "elements": '
        '[{"type":"obj", "bbox":[0,0,500,500], "desc":"thing"}]}}';
    // Historical conversion output: mossCanvasSize(1864) = 1872
    // (round-half-up to a multiple of 16). Half-frame box 936.
    const String legacyMossText =
        '{"width":1872,"height":1872, "bbox_coord_space":"abs", '
        '"bbox_format":"xyxy", "summary":{"caption":"old draft"}, '
        '"items":[{"label":"object", "caption":"thing", '
        '"bbox":[0,0,936,936]}]}';

    RepairLegacyMossCubit buildCubit({
      MossConversionService? conversionService,
    }) {
      session = _RecordingSession();
      session.seed(
        images: <AppImage>[
          makeImage('a', png('a.png'), <String, CaptionEntry>{
            'moss': const CaptionEntry(text: legacyMossText),
            'ideogram': const CaptionEntry(text: ideogramText),
          }),
        ],
      );
      return RepairLegacyMossCubit(
        session.service,
        conversionService:
            conversionService ??
            MossConversionService(
              dimensionLookup: (File _) async {
                return const ImageDimensions(width: 1864, height: 1864);
              },
            ),
      );
    }

    test('audit captures the Ideogram source category and text', () async {
      final RepairLegacyMossCubit cubit = buildCubit();
      await cubit.audit(sourceCategory: 'moss');
      final LegacyMossRepairPreview preview =
          cubit.state as LegacyMossRepairPreview;
      expect(preview.sourceCategory, 'moss');
      final MossRepairCandidate c = preview.candidates.single;
      expect(c.strategy, MossRepairStrategy.reconvert);
      expect(c.ideogramSourceCategory, 'ideogram');
      expect(c.ideogramSourceText, ideogramText);
      expect(c.mossText, legacyMossText);
      expect(c.destinationCategory, 'moss-repaired');
      expect(c.repairedPreview.single, isNotNull);
    });

    test('apply reconverts the IDEOGRAM text (not the MOSS caption) into the '
        'destination category', () async {
      final RepairLegacyMossCubit cubit = buildCubit();
      await cubit.audit(sourceCategory: 'moss');
      await cubit.applyRepairs();

      final LegacyMossRepairCompleted done =
          cubit.state as LegacyMossRepairCompleted;
      expect(done.repaired, 1);
      // The converted text went to the destination category, the source
      // MOSS category is untouched.
      final String destText = session.imageCaptions('a')!['moss-repaired']!;
      expect(destText, isNot(legacyMossText));
      final bool widthExact = destText.contains('"width":1864');
      expect(widthExact, isTrue);
      // Reconversion re-derived the box from the Ideogram source:
      // [0,0,500,500] normalized → [0,0,932,932].
      expect(destText, contains('[0,0,932,932]'));
      expect(session.imageCaptions('a')!['moss'], legacyMossText);
    });

    test('changed Ideogram source after audit is refused (stale result not '
        'written)', () async {
      final RepairLegacyMossCubit cubit = buildCubit();
      await cubit.audit(sourceCategory: 'moss');
      // The user edits the Ideogram source after the audit.
      session.editCaption('a', 'ideogram', 'edited source');
      await cubit.applyRepairs();

      final LegacyMossRepairCompleted done =
          cubit.state as LegacyMossRepairCompleted;
      expect(done.repaired, 0);
      expect(done.skipped, 1);
      expect(
        done.diagnostics.any(
          (MossFormatDiagnostic d) =>
              d.code == MossDiagnosticCodes.sourceChangedDuringConversion,
        ),
        isTrue,
      );
    });

    test(
      'changed MOSS caption after audit is refused before any conversion',
      () async {
        final RepairLegacyMossCubit cubit = buildCubit();
        await cubit.audit(sourceCategory: 'moss');
        session.editCaption('a', 'moss', 'edited draft');
        await cubit.applyRepairs();
        final LegacyMossRepairCompleted done =
            cubit.state as LegacyMossRepairCompleted;
        expect(done.repaired, 0);
        expect(done.skipped, 1);
      },
    );

    test('reviewer strategy override: rescale keeps MOSS wording', () async {
      final RepairLegacyMossCubit cubit = buildCubit();
      await cubit.audit(sourceCategory: 'moss');
      cubit.setStrategy(0, MossRepairStrategy.rescaleFrame);
      await cubit.applyRepairs();
      final LegacyMossRepairCompleted done =
          cubit.state as LegacyMossRepairCompleted;
      expect(done.repaired, 1);
      final String destText = session.imageCaptions('a')!['moss-repaired']!;
      // Rescale preserves the MOSS summary wording verbatim.
      expect(destText, contains('old draft'));
      // 936 * 1864/1872 = 932.0 exactly (outward rounding keeps 932).
      expect(destText, contains('[0,0,932,932]'));
    });

    test('EDITED draft defaults to rescale so user wording survives (reconvert '
        'is the explicit choice)', () async {
      session = _RecordingSession();
      session.seed(
        images: <AppImage>[
          makeImage('a', png('a.png'), <String, CaptionEntry>{
            'moss': const CaptionEntry(text: legacyMossText, isEdited: true),
            'ideogram': const CaptionEntry(text: ideogramText),
          }),
        ],
      );
      final RepairLegacyMossCubit cubit = RepairLegacyMossCubit(
        session.service,
        conversionService: MossConversionService(
          dimensionLookup: (File _) async {
            return const ImageDimensions(width: 1864, height: 1864);
          },
        ),
      );
      await cubit.audit(sourceCategory: 'moss');
      final LegacyMossRepairPreview preview =
          cubit.state as LegacyMossRepairPreview;
      // Deliberate default: rescale preserves the edited wording.
      expect(
        preview.candidates.single.strategy,
        MossRepairStrategy.rescaleFrame,
      );
      await cubit.applyRepairs();
      final LegacyMossRepairCompleted done =
          cubit.state as LegacyMossRepairCompleted;
      expect(done.repaired, 1);
      // The user's MOSS wording survived verbatim.
      expect(
        session.imageCaptions('a')!['moss-repaired'],
        contains('old draft'),
      );
    });

    test('per-row skip override prevents the write', () async {
      final RepairLegacyMossCubit cubit = buildCubit();
      await cubit.audit(sourceCategory: 'moss');
      cubit.setStrategy(0, MossRepairStrategy.skip);
      await cubit.applyRepairs();
      final LegacyMossRepairCompleted done =
          cubit.state as LegacyMossRepairCompleted;
      expect(done.repaired, 0);
    });

    test('Ideogram edited DURING the awaited conversion is refused '
        '(post-await recheck)', () async {
      // Deferred conversion service: the test edits the Ideogram source
      // while the conversion future is pending (Codex rev-2 finding 6).
      final RepairLegacyMossCubit cubit = buildCubit(
        conversionService: MossConversionService(
          dimensionLookup: (File _) async {
            // Simulate the await window: the user edits the Ideogram
            // source while conversion is "in flight".
            session.editCaption('a', 'ideogram', 'edited mid-flight');
            return const ImageDimensions(width: 1864, height: 1864);
          },
        ),
      );
      await cubit.audit(sourceCategory: 'moss');
      await cubit.applyRepairs();
      final LegacyMossRepairCompleted done =
          cubit.state as LegacyMossRepairCompleted;
      expect(done.repaired, 0);
      expect(done.skipped, 1);
      expect(
        done.diagnostics.any(
          (MossFormatDiagnostic d) =>
              d.code == MossDiagnosticCodes.sourceChangedDuringConversion,
        ),
        isTrue,
      );
      // Nothing was written to the destination.
      expect(session.imageCaptions('a')!.containsKey('moss-repaired'), isFalse);
    });

    test(
      'destination created DURING the awaited conversion is not overwritten',
      () async {
        bool raced = false;
        final RepairLegacyMossCubit cubit = buildCubit(
          conversionService: MossConversionService(
            dimensionLookup: (File _) async {
              if (!raced) {
                raced = true;
                // A destination caption appears mid-flight.
                session.editCaption('a', 'moss-repaired', 'appeared');
              }
              return const ImageDimensions(width: 1864, height: 1864);
            },
          ),
        );
        await cubit.audit(sourceCategory: 'moss');
        await cubit.applyRepairs();
        final LegacyMossRepairCompleted done =
            cubit.state as LegacyMossRepairCompleted;
        expect(done.repaired, 0);
        expect(done.skipped, 1);
        expect(
          done.diagnostics.any(
            (MossFormatDiagnostic d) =>
                d.code == MossDiagnosticCodes.destinationCollision,
          ),
          isTrue,
        );
        // The mid-flight destination text was preserved verbatim.
        expect(session.imageCaptions('a')!['moss-repaired'], 'appeared');
      },
    );

    test('arbitrary (non-legacy) mismatches are never auto-repaired', () async {
      final File arbitrary = File('${tempDir.path}/b.png')
        ..writeAsBytesSync(pngBytes(1864, 1864));
      session = _RecordingSession();
      session.seed(
        images: <AppImage>[
          makeImage('b', arbitrary, const <String, CaptionEntry>{
            // 1024² declaration against a 1864² image = mismatch.
            'moss': CaptionEntry(
              text:
                  '{"width":1024,"height":1024,"bbox_coord_space":"abs",'
                  '"bbox_format":"xyxy","summary":{"caption":"imported"},'
                  '"items":[]}',
            ),
          }),
        ],
      );
      final RepairLegacyMossCubit cubit = RepairLegacyMossCubit(
        session.service,
        conversionService: MossConversionService(
          dimensionLookup: (File _) async {
            return const ImageDimensions(width: 1864, height: 1864);
          },
        ),
      );
      await cubit.audit(sourceCategory: 'moss');
      final LegacyMossRepairPreview preview =
          cubit.state as LegacyMossRepairPreview;
      expect(preview.candidates.single.strategy, MossRepairStrategy.skip);
      await cubit.applyRepairs();
      expect((cubit.state as LegacyMossRepairCompleted).repaired, 0);
    });
  });
}

class _RecordingSession {
  _RecordingSession() {
    service = CaptionSessionService(
      fileStore: _FakeStore(),
      filterEngine: _Passthrough(),
    );
  }

  late final CaptionSessionService service;

  void seed({required List<AppImage> images}) {
    service.adopt(
      ImageListState(
        images: images,
        folderPath: tempPath,
        currentImageId: images.first.id,
        categories: const <String>['default', 'moss', 'ideogram'],
      ),
    );
  }

  String get tempPath =>
      Directory.systemTemp.createTempSync('moss_repair_session').path;

  Map<String, String>? imageCaptions(String imageId) {
    for (final AppImage i in service.state.images) {
      if (i.id == imageId) {
        return i.captions.map(
          (String k, CaptionEntry v) => MapEntry<String, String>(k, v.text),
        );
      }
    }
    return null;
  }

  void editCaption(String imageId, String category, String text) {
    final List<AppImage> images = List<AppImage>.from(service.state.images);
    final int index = images.indexWhere((AppImage i) => i.id == imageId);
    final AppImage image = images[index];
    images[index] = image.copyWith(
      captions: <String, CaptionEntry>{
        ...image.captions,
        category: CaptionEntry(text: text, isEdited: true),
      },
    );
    service.replaceState(service.state.copyWith(images: images));
  }
}

class _FakeStore implements CaptionFileStore {
  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) => throw UnimplementedError();

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) =>
      Future<Either<Failure, CaptionDatabase>>.value(
        Right<Failure, CaptionDatabase>(
          CaptionDatabase(
            categories: <String>['default'],
            images: <CaptionData>[],
          ),
        ),
      );

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {}

  @override
  Future<void> removeImage(File imageFile) async {}

  @override
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  ) async {}

  @override
  Future<void> removeCaptionFiles(
    String folderPath,
    List<AppImage> images,
  ) async {}

  @override
  Future<AppImage> duplicateImage(AppImage originalImage) =>
      throw UnimplementedError();

  @override
  int compareNatural(String a, String b) => a.compareTo(b);

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) async => images;

  @override
  Future<AppImage> getSingleImageSize(AppImage image) async => image;
}

class _Passthrough implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => images;
}
