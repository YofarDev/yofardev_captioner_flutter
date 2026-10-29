import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';
import 'package:yofardev_captioner/core/models/moss_conversion.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';
import 'package:yofardev_captioner/core/models/structured_caption_document.dart';

IdeogramCaption _sampleIdeogram() => const IdeogramCaption(
  highLevelDescription: 'A man sits at a desk with two monitors.',
  styleDescription: IdeogramStyleDescription(
    aesthetics: 'moody, cinematic, desaturated',
    lighting: 'amber pool from a desk lamp',
    medium: 'photograph',
    photo: '35mm, shallow depth of field',
    colorPalette: <String>['#222222', '#ddcc99'],
  ),
  compositionalDeconstruction: IdeogramCompositionalDeconstruction(
    background: 'white-painted wall, gray concrete floor',
    elements: <IdeogramElement>[
      IdeogramElement(
        type: 'obj',
        bbox: <int>[100, 200, 500, 600],
        desc: 'A wooden desk with a dark walnut finish.',
      ),
      IdeogramElement(
        type: 'text',
        bbox: <int>[600, 100, 700, 300],
        desc: 'White sans-serif sticker on the monitor bezel.',
        text: 'HELLO',
      ),
      IdeogramElement(type: 'obj', desc: 'Element without a bbox'),
    ],
  ),
);

void main() {
  group('mossCanvasSize', () {
    test('snaps to positive multiples of 16', () {
      expect(mossCanvasSize(imageWidth: 1000, imageHeight: 640), (1008, 640));
      expect(mossCanvasSize(imageWidth: 1003, imageHeight: 641), (1008, 640));
      expect(mossCanvasSize(imageWidth: 8, imageHeight: 0), (16, 16));
    });
  });

  group('mossFromIdeogram', () {
    test(
      'folds high_level_description and background into summary.caption',
      () {
        final MossLayoutCaption moss = mossFromIdeogram(
          _sampleIdeogram(),
          width: 1024,
          height: 1024,
        ).caption;
        expect(
          moss.summary.caption,
          'A man sits at a desk with two monitors. '
          'white-painted wall, gray concrete floor',
        );
      },
    );

    test('builds meta tags from style fields', () {
      final MossLayoutCaption moss = mossFromIdeogram(
        _sampleIdeogram(),
        width: 1024,
        height: 1024,
      ).caption;
      expect(moss.summary.meta, <String>[
        'photograph',
        'moody',
        'cinematic',
        'desaturated',
        'amber pool from a desk lamp',
        '35mm, shallow depth of field',
      ]);
      expect(moss.summary.palette, <String>['#222222', '#ddcc99']);
    });

    test('converts yxyx 0-1000 bboxes to xyxy pixel bboxes', () {
      final MossLayoutCaption moss = mossFromIdeogram(
        _sampleIdeogram(),
        width: 1000,
        height: 1000,
      ).caption;
      expect(moss.items[0].bbox, <int>[200, 100, 600, 500]);
      expect(moss.items[0].label, 'object');
      expect(moss.items[1].label, 'text');
      expect(moss.items[1].text, 'HELLO');
    });

    test('drops elements without a bbox', () {
      final MossLayoutCaption moss = mossFromIdeogram(
        _sampleIdeogram(),
        width: 1024,
        height: 1024,
      ).caption;
      expect(moss.items, hasLength(2));
    });

    test('round-trip through ideogramFromMoss preserves content', () {
      final IdeogramCaption original = _sampleIdeogram();
      final MossLayoutCaption moss = mossFromIdeogram(
        original,
        width: 1000,
        height: 1000,
      ).caption;
      final IdeogramCaption back = ideogramFromMoss(moss).caption;
      expect(
        back.highLevelDescription,
        '${original.highLevelDescription} '
        'white-painted wall, gray concrete floor',
      );
      expect(back.styleDescription.medium, 'photograph');
      expect(back.compositionalDeconstruction.elements, hasLength(2));
      expect(back.compositionalDeconstruction.elements[0].type, 'obj');
      expect(back.compositionalDeconstruction.elements[1].text, 'HELLO');
      // bbox drift is limited to rounding: pixel round-trip on a 1000px
      // canvas is exact.
      expect(back.compositionalDeconstruction.elements[0].bbox, <int>[
        100,
        200,
        500,
        600,
      ]);
    });
  });

  group('ideogramFromMoss', () {
    test('recovers the medium token from meta and joins the rest', () {
      const MossLayoutCaption moss = MossLayoutCaption(
        width: 512,
        height: 256,
        summary: MossSummary(
          caption: 'Global summary.',
          meta: <String>['studio photography', 'painting', 'soft light'],
          palette: <String>['ivory'],
        ),
        items: <MossItem>[
          MossItem(
            label: 'character',
            caption: 'A standing figure.',
            bbox: <int>[0, 0, 256, 256],
          ),
        ],
      );
      final MossToIdeogramResult result = ideogramFromMoss(moss);
      expect(result.caption.styleDescription.medium, 'painting');
      expect(
        result.caption.styleDescription.aesthetics,
        'studio photography, soft light',
      );
      expect(result.caption.styleDescription.colorPalette, <String>['ivory']);
      // character collapses to obj (documented lossy step).
      expect(
        result.caption.compositionalDeconstruction.elements[0].type,
        'obj',
      );
      expect(result.droppedItems, 0);
    });

    test('defaults medium to photograph and counts dropped items', () {
      const MossLayoutCaption moss = MossLayoutCaption(
        width: 512,
        height: 512,
        summary: MossSummary(caption: 'x'),
        items: <MossItem>[
          MossItem(caption: 'no bbox here'),
          MossItem(caption: 'fine', bbox: <int>[0, 0, 512, 512]),
        ],
      );
      final MossToIdeogramResult result = ideogramFromMoss(moss);
      expect(result.caption.styleDescription.medium, 'photograph');
      expect(result.droppedItems, 1);
    });

    test('converts pixel bboxes to clamped normalized yxyx', () {
      const MossLayoutCaption moss = MossLayoutCaption(
        width: 512,
        height: 512,
        summary: MossSummary(caption: 'x'),
        items: <MossItem>[
          MossItem(caption: 'full canvas', bbox: <int>[0, 0, 512, 512]),
          MossItem(caption: 'quarter', bbox: <int>[256, 256, 512, 512]),
        ],
      );
      final IdeogramCaption caption = ideogramFromMoss(moss).caption;
      expect(caption.compositionalDeconstruction.elements[0].bbox, <int>[
        0,
        0,
        1000,
        1000,
      ]);
      expect(caption.compositionalDeconstruction.elements[1].bbox, <int>[
        500,
        500,
        1000,
        1000,
      ]);
    });
  });

  group('CaptionFormat detection', () {
    test('detects ideogram, moss and plain', () {
      final String ideogramJson = _sampleIdeogram().toJsonString();
      final String mossJson = mossFromIdeogram(
        _sampleIdeogram(),
        width: 1024,
        height: 1024,
      ).caption.toJsonString();
      expect(detectCaptionFormat(ideogramJson), CaptionFormat.ideogram);
      expect(detectCaptionFormat(mossJson), CaptionFormat.moss);
      expect(detectCaptionFormat('plain caption'), CaptionFormat.plain);
      expect(detectCaptionFormat(''), CaptionFormat.plain);
    });
  });
}
