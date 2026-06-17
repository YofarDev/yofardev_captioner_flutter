import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/utils/bbox_utils.dart';

void main() {
  group('kBboxColors', () {
    test('exposes eight overlay colors', () {
      expect(kBboxColors.length, 8);
    });
  });

  group('getContainRect', () {
    test('letterboxes when container is wider than image', () {
      // Container 200x100 (aspect 2.0), image 100x100 (aspect 1.0).
      final Rect rect = getContainRect(
        const Size(200, 100),
        const Size(100, 100),
      );
      // Image fills height (100), painted width = 100, centered → x 50..150.
      expect(rect.width, 100);
      expect(rect.height, 100);
      expect(rect.left, 50);
      expect(rect.top, 0);
    });

    test('pillarboxes when container is taller than image', () {
      // Container 100x200 (aspect 0.5), image 100x100 (aspect 1.0).
      final Rect rect = getContainRect(
        const Size(100, 200),
        const Size(100, 100),
      );
      expect(rect.width, 100);
      expect(rect.height, 100);
      expect(rect.left, 0);
      expect(rect.top, 50);
    });

    test('fills container when aspects match', () {
      final Rect rect = getContainRect(
        const Size(200, 100),
        const Size(200, 100),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 200, 100));
    });
  });

  group('bboxToRect', () {
    test('maps Ideogram [y1,x1,y2,x2] into painted rect', () {
      // Painted rect 0,0 → 1000x1000 for easy math.
      const Rect painted = Rect.fromLTWH(0, 0, 1000, 1000);
      final Rect rect = bboxToRect(const <int>[100, 200, 400, 800], painted);
      // top = 100/1000*1000 = 100, left = 200, bottom = 400, right = 800.
      expect(rect, const Rect.fromLTRB(200, 100, 800, 400));
    });

    test('offsets by painted rect origin', () {
      const Rect painted = Rect.fromLTWH(50, 60, 1000, 1000);
      final Rect rect = bboxToRect(const <int>[0, 0, 1000, 1000], painted);
      expect(rect, const Rect.fromLTRB(50, 60, 1050, 1060));
    });
  });

  group('rectToBbox', () {
    test('converts a screen rect back to Ideogram space', () {
      const Rect painted = Rect.fromLTWH(0, 0, 1000, 1000);
      final List<int> bbox = rectToBbox(
        const Rect.fromLTRB(200, 100, 800, 400),
        painted,
      );
      expect(bbox, <int>[100, 200, 400, 800]);
    });

    test('round-trips through bboxToRect', () {
      const Rect painted = Rect.fromLTWH(10, 20, 500, 700);
      const List<int> original = <int>[123, 456, 789, 321];
      final Rect asRect = bboxToRect(original, painted);
      final List<int> back = rectToBbox(asRect, painted);
      expect(back, original);
    });

    test('clamps to 0..1000', () {
      const Rect painted = Rect.fromLTWH(0, 0, 100, 100);
      // Rect entirely outside painted area on the negative side.
      final List<int> bbox = rectToBbox(
        const Rect.fromLTRB(-500, -500, -100, -100),
        painted,
      );
      expect(bbox, everyElement(0));
    });
  });

  group('getContrastColor', () {
    test('returns dark text for bright backgrounds', () {
      expect(getContrastColor(Colors.white), Colors.black87);
      expect(getContrastColor(const Color(0xFFFFFFFF)), Colors.black87);
    });

    test('returns light text for dark backgrounds', () {
      expect(getContrastColor(Colors.black), Colors.white);
      expect(getContrastColor(const Color(0xFF000000)), Colors.white);
    });
  });
}
