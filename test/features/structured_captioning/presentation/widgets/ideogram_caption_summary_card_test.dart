import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/ideogram_caption_summary_card.dart';

void main() {
  // ponytail: minimal harness — just MaterialApp + Scaffold wrapping the card.
  Widget harness(String json) => MaterialApp(
    home: Scaffold(
      body: IdeogramCaptionSummaryCard(
        jsonString: json,
        imageFile: File('/x/y.jpg'),
        activeCategory: 'default',
      ),
    ),
  );

  group('IdeogramCaptionSummaryCard.isIdeogramJson (static)', () {
    test('returns false for plain text', () {
      expect(IdeogramCaptionSummaryCard.isIdeogramJson('hello'), isFalse);
      expect(IdeogramCaptionSummaryCard.isIdeogramJson(''), isFalse);
    });

    test('returns false for JSON missing required keys', () {
      expect(IdeogramCaptionSummaryCard.isIdeogramJson('{"foo": 1}'), isFalse);
    });

    test('returns true for JSON with both required keys', () {
      const String json =
          '{"high_level_description":"x","compositional_deconstruction":{}}';
      expect(IdeogramCaptionSummaryCard.isIdeogramJson(json), isTrue);
    });

    test('returns false for malformed JSON', () {
      expect(IdeogramCaptionSummaryCard.isIdeogramJson('{not json'), isFalse);
    });
  });

  group('IdeogramCaptionSummaryCard rendering', () {
    testWidgets(
      'renders high-level description, background, and element counts',
      (WidgetTester tester) async {
        const IdeogramCaption caption = IdeogramCaption(
          highLevelDescription: 'A cozy room',
          styleDescription: IdeogramStyleDescription(
            aesthetics: 'warm',
            lighting: 'soft',
            medium: 'photograph',
            colorPalette: <String>[],
          ),
          compositionalDeconstruction: IdeogramCompositionalDeconstruction(
            background: 'wooden wall',
            elements: <IdeogramElement>[
              IdeogramElement(type: 'obj', desc: 'sofa'),
              IdeogramElement(type: 'obj', desc: 'lamp'),
              IdeogramElement(type: 'text', desc: 'sign', text: 'HI'),
            ],
          ),
        );

        await tester.pumpWidget(harness(caption.toJsonString()));

        expect(find.text('A cozy room'), findsOneWidget);
        expect(find.text('wooden wall'), findsOneWidget);
        // 2 objs + 1 text → "2 objs · 1 text".
        expect(find.text('2 objs · 1 text'), findsOneWidget);
      },
    );

    testWidgets('renders singular "obj" when only one object element', (
      WidgetTester tester,
    ) async {
      const IdeogramCaption caption = IdeogramCaption(
        highLevelDescription: 'h',
        styleDescription: IdeogramStyleDescription(
          aesthetics: '',
          lighting: '',
          medium: 'photograph',
          colorPalette: <String>[],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: '',
          elements: <IdeogramElement>[
            IdeogramElement(type: 'obj', desc: 'one'),
          ],
        ),
      );

      await tester.pumpWidget(harness(caption.toJsonString()));
      expect(find.text('1 obj'), findsOneWidget);
    });

    testWidgets('omits text count when no text elements', (
      WidgetTester tester,
    ) async {
      const IdeogramCaption caption = IdeogramCaption(
        highLevelDescription: 'h',
        styleDescription: IdeogramStyleDescription(
          aesthetics: '',
          lighting: '',
          medium: 'photograph',
          colorPalette: <String>[],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: '',
          elements: <IdeogramElement>[
            IdeogramElement(type: 'obj', desc: 'a'),
            IdeogramElement(type: 'obj', desc: 'b'),
          ],
        ),
      );

      await tester.pumpWidget(harness(caption.toJsonString()));
      expect(find.text('2 objs'), findsOneWidget);
    });

    testWidgets('renders raw text fallback when JSON is invalid', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness('not valid json'));
      expect(find.text('not valid json'), findsOneWidget);
    });

    testWidgets('renders style tags when present', (WidgetTester tester) async {
      const IdeogramCaption caption = IdeogramCaption(
        highLevelDescription: 'h',
        styleDescription: IdeogramStyleDescription(
          aesthetics: 'dramatic',
          lighting: 'golden hour',
          medium: 'photograph',
          colorPalette: <String>[],
        ),
        compositionalDeconstruction: IdeogramCompositionalDeconstruction(
          background: '',
          elements: <IdeogramElement>[],
        ),
      );

      await tester.pumpWidget(harness(caption.toJsonString()));
      expect(find.textContaining('photograph'), findsWidgets);
      expect(find.textContaining('dramatic'), findsWidgets);
      expect(find.textContaining('golden hour'), findsWidgets);
    });
  });
}
