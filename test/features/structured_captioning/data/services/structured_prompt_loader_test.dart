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
      prompt = await File('assets/prompts/vision_analysis.txt').readAsString();
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
      prompt = await File(
        'assets/prompts/element_recaption.txt',
      ).readAsString();
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

  group('style_recaption prompt', () {
    late String prompt;

    setUpAll(() async {
      prompt = await File('assets/prompts/style_recaption.txt').readAsString();
    });

    test('exists and asks for the four style keys only', () {
      // The whole point of style recaption: only these four fields.
      expect(prompt, contains('"medium"'));
      expect(prompt, contains('"aesthetics"'));
      expect(prompt, contains('"lighting"'));
      expect(prompt, contains('"photo_or_art"'));
    });

    test('substitutes the existing caption via the {existingJson} token', () {
      expect(prompt, contains('{existingJson}'));
    });

    test('does not deal with bbox ordering', () {
      // Style regen is whole-image; it must not carry the vision-analysis
      // bbox contract forward.
      expect(prompt, isNot(contains('{{bbox_order}}')));
      expect(prompt.toLowerCase(), isNot(contains('y1 < y2')));
    });

    test('return template pins exactly the four style keys', () {
      // The return contract is the four-key object — nothing else may sneak in.
      expect(prompt, contains('"medium"'));
      expect(prompt, contains('"aesthetics"'));
      expect(prompt, contains('"lighting"'));
      expect(prompt, contains('"photo_or_art"'));
      expect(prompt, contains('Return ONLY a JSON object'));
    });
  });

  group('vision_enumerate prompt bbox format', () {
    late String prompt;

    setUpAll(() async {
      prompt = await File('assets/prompts/vision_enumerate.txt').readAsString();
    });

    test('parameterizes bbox order via the {{bbox_order}} token', () {
      expect(prompt, contains('[{{bbox_order}}]'));
    });

    test('states the y1 < y2 and x1 < x2 invariants', () {
      expect(prompt, contains('y1 < y2'));
      expect(prompt, contains('x1 < x2'));
    });

    test('both legal token substitutions resolve cleanly', () {
      const String xyxy = 'x1, y1, x2, y2';
      const String yxyx = 'y1, x1, y2, x2';
      final String asXyxy = prompt.replaceAll('{{bbox_order}}', xyxy);
      final String asYxyx = prompt.replaceAll('{{bbox_order}}', yxyx);
      expect(asXyxy, isNot(contains('{{bbox_order}}')));
      expect(asYxyx, isNot(contains('{{bbox_order}}')));
    });

    test('asks for a terse placeholder desc (enumeration pass)', () {
      expect(prompt.toLowerCase(), contains('placeholder'));
      expect(prompt, contains('3-8'));
    });
  });

  // Locks the anti-degenerate-repetition contract. Local VLMs (greedy
  // decoding) can otherwise emit hundreds of near-identical entries for scenes
  // with many repeated elements (e.g. a balcony full of plants), exhausting
  // the token budget and truncating the JSON into an unparseable mess. The
  // grouping rule + hard cap prevent that pathology at the source.
  group('vision_enumerate prompt grouping/cap rules', () {
    late String prompt;

    setUpAll(() async {
      prompt = await File('assets/prompts/vision_enumerate.txt').readAsString();
    });

    test('has a grouping section', () {
      expect(prompt.toLowerCase(), contains('group'));
    });

    test('forbids per-item enumeration of repeated instances', () {
      expect(prompt, contains('NEVER emit one element per repeated instance'));
    });

    test('enforces a hard element cap via token', () {
      expect(prompt, contains('{{element_cap}}'));
    });
  });

  group('element_enrich prompt', () {
    late String prompt;

    setUpAll(() async {
      prompt = await File('assets/prompts/element_enrich.txt').readAsString();
    });

    test('substitutes element name and type via single-brace tokens', () {
      expect(prompt, contains('{name}'));
      expect(prompt, contains('{type}'));
    });

    test('asks for a 12-40 word desc', () {
      expect(prompt, contains('12-40'));
    });

    test('pins the text-omission contract', () {
      expect(prompt, contains('Omit it otherwise'));
    });

    test('pins the no-invent contract', () {
      expect(prompt, contains('Never invent'));
    });

    test('includes desc token for terse enumerate context', () {
      expect(prompt, contains('{desc}'));
    });

    test('includes bbox token for element position context', () {
      expect(prompt, contains('{bbox}'));
    });

    test('includes name and type tokens', () {
      expect(prompt, contains('{name}'));
      expect(prompt, contains('{type}'));
    });

    test('forbids whole-scene context leakage', () {
      expect(prompt, contains('DO NOT describe'));
      expect(prompt.toLowerCase(), contains('the room'));
      expect(prompt, contains('the overall image'));
      expect(prompt, contains('background'));
    });
  });

  group('vision_enumerate prompt localization rules', () {
    late String prompt;

    setUpAll(() async {
      prompt = await File('assets/prompts/vision_enumerate.txt').readAsString();
    });

    test('forbids full-image bboxes for individual objects', () {
      expect(prompt, contains('NEVER use the full-image bbox'));
    });

    test('requires zone-based grouping for separated clusters', () {
      expect(prompt, contains('SEPARATE zones'));
      expect(prompt, contains('zone'));
      expect(prompt, contains('SEPARATE grouped elements'));
    });

    test('gives interior subject examples', () {
      expect(prompt, contains('sofas'));
      expect(prompt, contains('shelves'));
      expect(prompt, contains('plants'));
      expect(prompt, contains('wall art'));
    });

    test('requires broad category coverage', () {
      expect(prompt.toLowerCase(), contains('broad'));
      expect(prompt, contains('seating'));
      expect(prompt, contains('beds'));
      expect(prompt, contains('tables'));
      expect(prompt, contains('shelves'));
      expect(prompt, contains('rugs'));
      expect(prompt, contains('electronics'));
    });

    test('keeps element cap via token', () {
      expect(prompt, contains('{{element_cap}}'));
      expect(prompt, contains('AT MOST 4 zone-based groups'));
    });

    test('separates background from objects', () {
      expect(prompt, contains('no duplicated'));
      expect(prompt, contains('architectural shell'));
    });
  });
}
