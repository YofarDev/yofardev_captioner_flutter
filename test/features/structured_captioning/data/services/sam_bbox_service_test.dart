// repo-test groups moved from structured_caption_repository_test.dart (Task 19).
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/sam_bbox_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/sam_process_service.dart';

void main() {
  final SamBboxService service = SamBboxService();

  // =========================================================================
  // isLikelyGroup
  // =========================================================================

  group('isLikelyGroup', () {
    test('returns true for plural names', () {
      expect(service.isLikelyGroup('Chairs', ''), isTrue);
      expect(service.isLikelyGroup('Potted Plants', ''), isTrue);
      expect(service.isLikelyGroup('Curtains', ''), isTrue);
      expect(service.isLikelyGroup('Books', ''), isTrue);
    });

    test('returns false for singular names', () {
      expect(service.isLikelyGroup('Chair', ''), isFalse);
      expect(service.isLikelyGroup('Cat', ''), isFalse);
      expect(service.isLikelyGroup('Window', ''), isFalse);
    });

    test('returns false for words ending in "ss"', () {
      expect(service.isLikelyGroup('Glass', ''), isFalse);
      expect(service.isLikelyGroup('Dress', ''), isFalse);
      expect(service.isLikelyGroup('Cross', ''), isFalse);
      expect(service.isLikelyGroup('Moss', ''), isFalse);
    });

    test('returns true when description has group keywords', () {
      expect(
        service.isLikelyGroup('Flower', 'a group of flowers in a vase'),
        isTrue,
      );
      expect(
        service.isLikelyGroup('Tree', 'cluster of trees in background'),
        isTrue,
      );
      expect(
        service.isLikelyGroup('Bottle', 'a row of bottles on shelf'),
        isTrue,
      );
      expect(
        service.isLikelyGroup('Candle', 'a pair of candles on table'),
        isTrue,
      );
      expect(service.isLikelyGroup('Book', 'several books stacked'), isTrue);
      expect(
        service.isLikelyGroup('Plate', 'multiple plates arranged'),
        isTrue,
      );
      expect(service.isLikelyGroup('Mug', 'a set of mugs'), isTrue);
      expect(service.isLikelyGroup('Herb', 'a bunch of herbs'), isTrue);
    });

    test('returns false for singular name without group description', () {
      expect(
        service.isLikelyGroup('Cat', 'a small orange cat sitting on a mat'),
        isFalse,
      );
      expect(service.isLikelyGroup('Table', 'a wooden dining table'), isFalse);
    });
  });

  // =========================================================================
  // matchDetectionsToObjects
  // =========================================================================

  group('matchDetectionsToObjects', () {
    test('returns VLM bboxes when no SAM detections', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 300, 300]),
        const VlmObjectBboxPair(name: 'Dog', bbox: <int>[400, 400, 600, 600]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        <SamDetection>[],
        vlmObjects,
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'Cat');
      expect(result[0].bbox, <int>[100, 100, 300, 300]);
      expect(result[1].name, 'Dog');
    });

    test('matches SAM detections to same-name VLM objects by proximity', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        // Cat at top-left (center ~150,150)
        const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 200, 200]),
        // Cat at bottom-right (center ~700,700)
        const VlmObjectBboxPair(name: 'Cat', bbox: <int>[650, 650, 750, 750]),
      ];

      final List<SamDetection> samDetections = <SamDetection>[
        // SAM finds a cat near bottom-right
        const SamDetection(name: 'Cat', bbox: <int>[660, 660, 740, 740]),
        // SAM finds a cat near top-left
        const SamDetection(name: 'Cat', bbox: <int>[110, 110, 190, 190]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      expect(result, hasLength(2));
      // First VLM cat (top-left) matched to second SAM (top-left).
      expect(result[0].bbox, <int>[110, 110, 190, 190]);
      // Second VLM cat (bottom-right) matched to first SAM (bottom-right).
      expect(result[1].bbox, <int>[660, 660, 740, 740]);
    });

    test('assigns single SAM detection to closest VLM object (1:N)', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Chair', bbox: <int>[100, 100, 200, 200]),
        const VlmObjectBboxPair(name: 'Chair', bbox: <int>[700, 700, 800, 800]),
      ];

      // Only one SAM detection — should go to the closest one.
      final List<SamDetection> samDetections = <SamDetection>[
        const SamDetection(name: 'Chair', bbox: <int>[690, 690, 810, 810]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      expect(result, hasLength(2));
      // First chair: no SAM match → VLM fallback.
      expect(result[0].bbox, <int>[100, 100, 200, 200]);
      // Second chair: SAM matched.
      expect(result[1].bbox, <int>[690, 690, 810, 810]);
    });

    test('fills unmatched VLM objects with their own bbox', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Tree', bbox: <int>[100, 100, 300, 300]),
        const VlmObjectBboxPair(name: 'Car', bbox: <int>[500, 500, 700, 700]),
      ];

      // SAM only detects Tree.
      final List<SamDetection> samDetections = <SamDetection>[
        const SamDetection(name: 'Tree', bbox: <int>[110, 110, 290, 290]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      expect(result[0].bbox, <int>[110, 110, 290, 290]); // SAM
      expect(result[1].bbox, <int>[500, 500, 700, 700]); // VLM fallback
    });

    test('handles objects with null bboxes', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Sky'),
        const VlmObjectBboxPair(name: 'Bird', bbox: <int>[200, 200, 300, 300]),
      ];

      final List<SamDetection> samDetections = <SamDetection>[
        const SamDetection(name: 'Bird', bbox: <int>[210, 210, 290, 290]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      expect(result[0].bbox, isNull); // Sky: no bbox anywhere
      expect(result[1].bbox, <int>[210, 210, 290, 290]); // Bird: SAM
    });

    test(
      'rejects SAM detection that landed on a different region (IoU gate)',
      () {
        // Mirrors the real failure: SAM returned the Nyon-sign bbox for BOTH
        // the "Nyon Sign" and "Text Banner" prompts. The Text-Banner SAM bbox
        // does not overlap the VLM's top-banner bbox at all (IoU = 0), so it
        // must fall back to the VLM bbox instead of duplicating Nyon Sign.
        final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
          const VlmObjectBboxPair(
            name: 'Nyon Sign',
            bbox: <int>[356, 756, 492, 988],
          ),
          const VlmObjectBboxPair(
            name: 'Text Banner',
            bbox: <int>[0, 0, 88, 998],
          ),
        ];

        final List<SamDetection> samDetections = <SamDetection>[
          // SAM correctly refines Nyon Sign.
          const SamDetection(
            name: 'Nyon Sign',
            bbox: <int>[353, 735, 504, 1000],
          ),
          // SAM wrongly returns the Nyon-sign region again for "Text Banner".
          const SamDetection(
            name: 'Text Banner',
            bbox: <int>[353, 735, 505, 1000],
          ),
        ];

        final List<SamDetection> result = service.matchDetectionsToObjects(
          samDetections,
          vlmObjects,
        );

        expect(result, hasLength(2));
        // Nyon Sign: SAM overlaps VLM well (IoU ~0.79) → kept.
        expect(result[0].bbox, <int>[353, 735, 504, 1000]);
        // Text Banner: SAM overlaps VLM with IoU 0 → rejected, VLM bbox used.
        expect(result[1].bbox, <int>[0, 0, 88, 998]);
      },
    );

    test('keeps SAM detection that overlaps the VLM region (IoU gate)', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 300, 300]),
      ];
      final List<SamDetection> samDetections = <SamDetection>[
        // Slightly larger but mostly overlapping — IoU well above 0.1.
        const SamDetection(name: 'Cat', bbox: <int>[90, 90, 320, 320]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      expect(result[0].bbox, <int>[90, 90, 320, 320]);
    });

    test('accepts SAM detection when VLM bbox is null (no spatial hint)', () {
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Sky'), // no bbox
      ];
      final List<SamDetection> samDetections = <SamDetection>[
        const SamDetection(name: 'Sky', bbox: <int>[0, 0, 500, 500]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      expect(result[0].bbox, <int>[0, 0, 500, 500]);
    });

    test('1:N assignment respects IoU gate (rejects far SAM)', () {
      // Two same-name VLM objects; the only SAM detection is near neither.
      final List<VlmObjectBboxPair> vlmObjects = <VlmObjectBboxPair>[
        const VlmObjectBboxPair(name: 'Cat', bbox: <int>[100, 100, 200, 200]),
        const VlmObjectBboxPair(name: 'Cat', bbox: <int>[700, 700, 800, 800]),
      ];
      final List<SamDetection> samDetections = <SamDetection>[
        const SamDetection(name: 'Cat', bbox: <int>[400, 400, 500, 500]),
      ];

      final List<SamDetection> result = service.matchDetectionsToObjects(
        samDetections,
        vlmObjects,
      );

      // Neither VLM cat overlaps the SAM detection → both fall back to VLM.
      expect(result[0].bbox, <int>[100, 100, 200, 200]);
      expect(result[1].bbox, <int>[700, 700, 800, 800]);
    });
  });

  // =========================================================================
  // computeIou
  // =========================================================================

  group('computeIou', () {
    test('returns 1.0 for identical bboxes', () {
      expect(
        computeIou(<int>[100, 100, 300, 300], <int>[100, 100, 300, 300]),
        1.0,
      );
    });

    test('returns 0 for non-overlapping bboxes', () {
      expect(computeIou(<int>[0, 0, 50, 50], <int>[60, 60, 100, 100]), 0.0);
    });

    test('returns 0 for null or malformed input', () {
      expect(computeIou(null, <int>[0, 0, 10, 10]), 0.0);
      expect(computeIou(<int>[0, 0], <int>[0, 0, 10, 10]), 0.0);
    });

    test('computes partial overlap', () {
      // a = 100x100 = 10000, b = 100x100 = 10000, intersection = 50x50 = 2500
      // union = 10000 + 10000 - 2500 = 17500 → IoU = 2500/17500 ≈ 0.1429.
      final double iou = computeIou(
        <int>[0, 0, 100, 100],
        <int>[50, 50, 150, 150],
      );
      expect(iou, closeTo(0.1429, 0.001));
    });

    test('Nyon Sign VLM vs SAM bbox has high IoU (~0.79)', () {
      final double iou = computeIou(
        <int>[356, 756, 492, 988],
        <int>[353, 735, 504, 1000],
      );
      expect(iou, closeTo(0.79, 0.02));
    });

    test('Text Banner VLM vs wrong SAM bbox has IoU 0', () {
      final double iou = computeIou(
        <int>[0, 0, 88, 998],
        <int>[353, 735, 505, 1000],
      );
      expect(iou, 0.0);
    });
  });
}
