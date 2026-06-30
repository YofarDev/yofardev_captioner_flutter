import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locks the bbox-format contract of the bundled Ideogram4 prompts.
///
/// Ideogram4 consumes bboxes in `[y1, x1, y2, x2]` (yxyx) order, 0–1000
/// normalized. The VLM-facing prompt parameterizes the *requested* order via a
/// `{{bbox_order}}` token (substituted at runtime by `StructuredCaptionRepository`
/// to whichever orientation the configured VLM emits best). The stored Ideogram
/// JSON is always yxyx regardless. These tests pin both the token contract on
/// the asset and the two legal substitution values. Reading the files directly
/// avoids rootBundle plumbing.
void main() {
  group('vision_analysis prompt bbox format', () {
    late String prompt;

    setUpAll(() async {
      prompt =
          await File('assets/prompts/vision_analysis.txt').readAsString();
    });

    test('parameterizes bbox order via the {{bbox_order}} token', () {
      // The asset must NOT hardcode an order; it must defer to the token so the
      // runtime can ask for whichever orientation the VLM emits best.
      expect(prompt, contains('[{{bbox_order}}]'));
    });

    test('never hardcodes a bbox order literal in the contract spots', () {
      // No hardcoded order may appear as the output contract — the token owns it.
      expect(prompt, isNot(contains('"bbox": [y1, x1, y2, x2]')));
      expect(prompt, isNot(contains('"bbox": [x1, y1, x2, y2]')));
      expect(prompt, isNot(contains('[y_min, x_min, y_max, x_max]')));
      expect(prompt, isNot(contains('[x_min, y_min, x_max, y_max]')));
    });

    test('states the y1 < y2 and x1 < x2 invariants', () {
      expect(prompt, contains('y1 < y2'));
      expect(prompt, contains('x1 < x2'));
    });

    test('both legal token substitutions resolve cleanly', () {
      // Mirrors the two values StructuredCaptionRepository._buildVisionPrompt
      // substitutes. Locks the token name + the two legal orderings.
      const String xyxy = 'x1, y1, x2, y2';
      const String yxyx = 'y1, x1, y2, x2';
      final String asXyxy = prompt.replaceAll('{{bbox_order}}', xyxy);
      final String asYxyx = prompt.replaceAll('{{bbox_order}}', yxyx);
      expect(asXyxy, isNot(contains('{{bbox_order}}')));
      expect(asYxyx, isNot(contains('{{bbox_order}}')));
      expect(asXyxy, contains('"bbox": [x1, y1, x2, y2]'));
      expect(asYxyx, contains('"bbox": [y1, x1, y2, x2]'));
    });
  });

  group('element_recaption prompt bbox format', () {
    late String prompt;

    setUpAll(() async {
      prompt =
          await File('assets/prompts/element_recaption.txt').readAsString();
    });

    test('references the stored element bbox in yxyx order', () {
      // This prompt feeds the already-stored Ideogram bbox back for context, so
      // it is always yxyx (the final storage format) — no token here.
      expect(prompt, contains('bbox [y1, x1, y2, x2]'));
    });

    test('never uses xyxy ordering', () {
      expect(prompt, isNot(contains('[x1, y1, x2, y2]')));
    });
  });
}
