import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/moss_format.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';

const String nativeExample =
    '{"bbox_coord_space":"abs_centralized", '
    '"bbox_format":"yxyx","summary":{"caption":"global scene"}, '
    '"items":[{"label":"object","caption":"a chair","bbox":[-100,-200,100,200]}]}';

const String draftExample =
    '{"width":512,"height":256, '
    '"bbox_coord_space":"abs","bbox_format":"xyxy", '
    '"summary":{"caption":"global scene"}, '
    '"items":[{"label":"object","caption":"a chair","bbox":[10,20,110,120]}]}';

const String legacyDraftNoMarkers =
    '{"width":512,"height":256,"summary":{"caption":"legacy"},'
    '"items":[{"label":"object","caption":"a chair","bbox":[10,20,110,120]}]}';

void main() {
  group('classifyMossJson', () {
    test('native markers classify as native', () {
      final MossJsonClassification c = classifyMossJson(
        jsonDecode(nativeExample) as Map<String, dynamic>,
      );
      expect(c.contract, MossCoordinateContract.native);
      expect(c.explicitMarkers, isTrue);
    });

    test('draft markers classify as draft', () {
      final MossJsonClassification c = classifyMossJson(
        jsonDecode(draftExample) as Map<String, dynamic>,
      );
      expect(c.contract, MossCoordinateContract.draft);
      expect(c.explicitMarkers, isTrue);
    });

    test('absent markers fall back to legacy draft shape', () {
      final MossJsonClassification c = classifyMossJson(
        jsonDecode(legacyDraftNoMarkers) as Map<String, dynamic>,
      );
      expect(c.contract, MossCoordinateContract.draft);
      expect(c.explicitMarkers, isFalse);
    });

    test(
      'unknown combinations are unsupported, never mapped onto a contract',
      () {
        // Codex review: unknown markers were previously accepted as native by
        // parseMossNative. Every explicit-but-unrecognized combination must be
        // refused by both parsers.
        const List<String> badMarkerSets = <String>[
          '"bbox_coord_space":"weird","bbox_format":"xyxy"',
          '"bbox_coord_space":"abs","bbox_format":"yxyx"',
          '"bbox_coord_space":"abs_centralized","bbox_format":"xyxy"',
          '"bbox_coord_space":5,"bbox_format":"yxyx"',
        ];
        for (final String markers in badMarkerSets) {
          final Map<String, dynamic> json =
              jsonDecode('{$markers,"summary":{"caption":"x"},"items":[]}')
                  as Map<String, dynamic>;
          expect(classifyMossJson(json).contract, isNull, reason: markers);

          final ({
            MossLayoutCaption? caption,
            List<MossFormatDiagnostic> diagnostics,
          })
          draft = parseMossDraft(
            '{$markers,"width":64,"height":64,"summary":{"caption":"x"},'
            '"items":[]}',
          );
          expect(draft.caption, isNull, reason: markers);
          expect(
            draft.diagnostics.any(
              (MossFormatDiagnostic d) =>
                  d.code == MossDiagnosticCodes.unsupportedMarkers,
            ),
            isTrue,
            reason: markers,
          );

          final ({
            MossLayoutCaption? caption,
            List<MossFormatDiagnostic> diagnostics,
          })
          native = parseMossNative(
            '{$markers,"summary":{"caption":"x"},"items":[]}',
            canvasWidth: 64,
            canvasHeight: 64,
          );
          expect(native.caption, isNull, reason: markers);
        }
      },
    );
  });

  group('parseMossDraft', () {
    test('opens explicit-marker drafts', () {
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossDraft(draftExample);
      expect(result.diagnostics, isEmpty);
      expect(result.caption!.width, 512);
      expect(result.caption!.height, 256);
      expect(result.caption!.items.single.bbox, <int>[10, 20, 110, 120]);
    });

    test('opens legacy drafts without markers', () {
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossDraft(legacyDraftNoMarkers);
      expect(result.diagnostics, isEmpty);
      expect(result.caption!.summary.caption, 'legacy');
    });

    test('rejects a native prompt as a draft', () {
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossDraft(nativeExample);
      expect(result.caption, isNull);
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.nativeMarkersInDraftPath,
        ),
        isTrue,
      );
    });

    test('rejects missing canvas instead of defaulting to 1024', () {
      const String noCanvas = '{"summary":{"caption":"x"},"items":[]}';
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossDraft(noCanvas);
      expect(result.caption, isNull);
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.missingCanvasSize,
        ),
        isTrue,
      );
    });

    test('reports out-of-bounds and reversed boxes as errors', () {
      const String bad =
          '{"width":100,"height":100,"summary":{"caption":"x"},"items":['
          '{"label":"object","caption":"oob","bbox":[0,0,200,50]},'
          '{"label":"object","caption":"rev","bbox":[50,50,10,20]}]}';
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossDraft(bad);
      expect(result.caption, isNull);
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.bboxOutOfBounds,
        ),
        isTrue,
      );
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.reversedBbox,
        ),
        isTrue,
      );
    });
  });

  group('parseMossNative', () {
    test(
      'converts centered yxyx back to top-left xyxy against a known canvas',
      () {
        final ({
          MossLayoutCaption? caption,
          List<MossFormatDiagnostic> diagnostics,
        })
        result = parseMossNative(
          nativeExample,
          canvasWidth: 1024,
          canvasHeight: 1024,
        );
        expect(result.diagnostics, isEmpty);
        expect(result.caption!.width, 1024);
        // yxyx [-100,-200,100,200] → xyxy [x1,y1,x2,y2] = [312,412,712,612]
        expect(result.caption!.items.single.bbox, <int>[312, 412, 712, 612]);
      },
    );

    test('refuses drafts and never invents a canvas', () {
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossNative(
        draftExample,
        canvasWidth: 512,
        canvasHeight: 256,
      );
      expect(result.caption, isNull);
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.draftMarkersInNativePath,
        ),
        isTrue,
      );
    });

    test('reports out-of-canvas native boxes', () {
      const String oob =
          '{"bbox_coord_space":"abs_centralized",'
          '"bbox_format":"yxyx","summary":{"caption":"x"},'
          '"items":[{"label":"object","caption":"big","bbox":[-900,-900,900,900]}]}';
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = parseMossNative(oob, canvasWidth: 512, canvasHeight: 512);
      expect(result.caption, isNull);
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code == MossDiagnosticCodes.bboxOutOfBounds,
        ),
        isTrue,
      );
    });
  });

  group('toNativePromptString', () {
    test(
      'emits the documented schema and round-trips through parseMossNative',
      () {
        final MossLayoutCaption draft = MossLayoutCaption.fromJson(
          jsonDecode(draftExample) as Map<String, dynamic>,
        );
        final String native = toNativePromptString(
          draft,
          outputWidth: 512,
          outputHeight: 256,
        );
        expect(native, contains('"bbox_coord_space":"abs_centralized"'));
        expect(native, contains('"bbox_format":"yxyx"'));
        final ({
          MossLayoutCaption? caption,
          List<MossFormatDiagnostic> diagnostics,
        })
        result = parseMossNative(native, canvasWidth: 512, canvasHeight: 256);
        expect(result.diagnostics, isEmpty);
        // floor/ceil around the center: [10,20,110,120] → centered yxyx
        // [-108,-246,8,46] → back to [10,20,110,120]
        expect(result.caption!.items.single.bbox, <int>[10, 20, 110, 120]);
      },
    );

    test('refuses a draft whose canvas is not the output frame', () {
      final MossLayoutCaption draft = MossLayoutCaption.fromJson(
        jsonDecode(draftExample) as Map<String, dynamic>,
      );
      expect(
        () =>
            toNativePromptString(draft, outputWidth: 1024, outputHeight: 1024),
        throwsStateError,
      );
    });
  });

  group('validateMossDraftGeometry', () {
    test('legacy tolerance downgrades geometry errors to warnings', () {
      const MossLayoutCaption draft = MossLayoutCaption(
        width: 100,
        height: 100,
        summary: MossSummary(caption: 'x'),
        items: <MossItem>[
          MossItem(caption: 'oob', bbox: <int>[0, 0, 200, 50]),
        ],
      );
      final List<MossFormatDiagnostic> strict = validateMossDraftGeometry(
        draft,
      );
      final List<MossFormatDiagnostic> tolerant = validateMossDraftGeometry(
        draft,
        strictness: MossValidationStrictness.legacyTolerant,
      );
      expect(
        strict.every(
          (MossFormatDiagnostic e) =>
              e.severity == MossDiagnosticSeverity.error,
        ),
        isTrue,
      );
      expect(
        tolerant.every(
          (MossFormatDiagnostic e) =>
              e.severity == MossDiagnosticSeverity.warning,
        ),
        isTrue,
      );
    });
  });
}
