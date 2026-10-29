import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';
import 'package:yofardev_captioner/core/models/moss_layout_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/structured_caption_summary_card.dart';

void main() {
  // ponytail: minimal harness — just MaterialApp + Scaffold wrapping the card.
  Widget harness(String json) => MaterialApp(
    home: Scaffold(
      body: StructuredCaptionSummaryCard(
        jsonString: json,
        imageFile: File('/x/y.jpg'),
        activeCategory: 'default',
      ),
    ),
  );

  group('StructuredCaptionSummaryCard rendering', () {
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

  group('StructuredCaptionSummaryCard MOSS rendering', () {
    testWidgets('renders summary caption, meta tags and item counts', (
      WidgetTester tester,
    ) async {
      const MossLayoutCaption caption = MossLayoutCaption(
        width: 1024,
        height: 1024,
        summary: MossSummary(
          caption: 'A studio scene',
          meta: <String>['product campaign', 'soft light'],
          canvas: 'single',
        ),
        items: <MossItem>[
          MossItem(caption: 'cup', bbox: <int>[0, 0, 10, 10]),
          MossItem(caption: 'plate', bbox: <int>[20, 20, 30, 30]),
          MossItem(
            label: 'text',
            caption: 'title',
            text: 'HI',
            bbox: <int>[40, 40, 50, 50],
          ),
        ],
      );

      await tester.pumpWidget(harness(caption.toJsonString()));

      expect(find.text('A studio scene'), findsOneWidget);
      expect(find.text('product campaign · soft light'), findsOneWidget);
      expect(find.text('2 objs · 1 text · single'), findsOneWidget);
    });

    testWidgets('omits canvas when absent', (WidgetTester tester) async {
      const MossLayoutCaption caption = MossLayoutCaption(
        width: 1024,
        height: 1024,
        summary: MossSummary(caption: 's'),
        items: <MossItem>[
          MossItem(caption: 'cup', bbox: <int>[0, 0, 1, 1]),
        ],
      );

      await tester.pumpWidget(harness(caption.toJsonString()));
      expect(find.text('1 obj'), findsOneWidget);
    });
  });
}
