import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/moss_conversion.dart';
import 'package:yofardev_captioner/core/models/moss_format.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';
import 'package:yofardev_captioner/core/models/moss_repair.dart';

void main() {
  group('auditMossFrame', () {
    test('exact dimensions classify as exact', () {
      expect(
        auditMossFrame(
          draftWidth: 1864,
          draftHeight: 1864,
          actualWidth: 1864,
          actualHeight: 1864,
        ),
        MossFrameAuditResult.exact,
      );
    });

    test('the historical 16px rounding classifies as legacyRounded', () {
      final (int, int) legacy = mossCanvasSize(
        imageWidth: 1864,
        imageHeight: 1864,
      );
      expect(
        auditMossFrame(
          draftWidth: legacy.$1,
          draftHeight: legacy.$2,
          actualWidth: 1864,
          actualHeight: 1864,
        ),
        MossFrameAuditResult.legacyRounded,
      );
    });

    test('arbitrary mismatches are NOT assumed legacy', () {
      expect(
        auditMossFrame(
          draftWidth: 1024,
          draftHeight: 1024,
          actualWidth: 1864,
          actualHeight: 1864,
        ),
        MossFrameAuditResult.mismatch,
      );
    });
  });

  group('rescaleMossDraftFrame', () {
    test('scales boxes and preserves wording/metadata verbatim', () {
      const MossLayoutCaption draft = MossLayoutCaption(
        width: 1856,
        height: 1856,
        summary: MossSummary(
          caption: 'keep this wording',
          meta: <String>['photograph'],
          palette: <String>['#111111'],
        ),
        items: <MossItem>[
          MossItem(
            label: 'character',
            caption: 'a person',
            bbox: <int>[0, 0, 928, 928],
            tags: <String>['protagonist'],
          ),
        ],
      );
      final ({
        MossLayoutCaption caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = rescaleMossDraftFrame(
        draft,
        actualWidth: 1864,
        actualHeight: 1864,
      );
      expect(result.diagnostics, isEmpty);
      expect(result.caption.width, 1864);
      expect(result.caption.summary.caption, 'keep this wording');
      expect(result.caption.summary.meta, <String>['photograph']);
      // 928 * 1864/1856 = 932.008... → left floor 0, right ceil 933
      expect(result.caption.items.single.bbox, <int>[0, 0, 933, 933]);
      expect(result.caption.items.single.label, 'character');
      expect(result.caption.items.single.tags, <String>['protagonist']);
    });

    test('1px boxes survive downscale (rounding is outward), zero-area '
        'inputs are dropped', () {
      const MossLayoutCaption draft = MossLayoutCaption(
        width: 1000,
        height: 1000,
        summary: MossSummary(caption: 'x'),
        items: <MossItem>[
          // 1px wide — outward rounding (floor/ceil) must keep it alive.
          MossItem(caption: 'thin', bbox: <int>[10, 10, 11, 20]),
          // degenerate source box — must be dropped with a diagnostic.
          MossItem(caption: 'degenerate', bbox: <int>[10, 10, 10, 20]),
        ],
      );
      final ({
        MossLayoutCaption caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      result = rescaleMossDraftFrame(
        draft,
        actualWidth: 500,
        actualHeight: 500,
      );
      expect(result.caption.items, hasLength(1));
      expect(result.caption.items.single.caption, 'thin');
      expect(
        result.diagnostics.any(
          (MossFormatDiagnostic e) =>
              e.code.name == 'zeroAreaBbox' || e.code.name == 'itemDropped',
        ),
        isTrue,
      );
    });
  });
}
