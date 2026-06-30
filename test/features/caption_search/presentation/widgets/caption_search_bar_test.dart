import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/caption_search/logic/caption_search_cubit.dart';
import 'package:yofardev_captioner/features/caption_search/presentation/widgets/caption_search_bar.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

import 'caption_search_bar_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit])
void main() {
  late MockImageListCubit mockImageListCubit;
  late CaptionSearchCubit captionSearchCubit;

  setUp(() {
    mockImageListCubit = MockImageListCubit();
    when(mockImageListCubit.state).thenReturn(const ImageListState());
    when(
      mockImageListCubit.stream,
    ).thenAnswer((_) => const Stream<ImageListState>.empty());
    when(
      mockImageListCubit.getAllUniqueTags(),
    ).thenReturn(<String>{'sunset', 'beach', 'mountain'});
    when(
      mockImageListCubit.getAllUniqueMediums(),
    ).thenReturn(<String>{'photograph', 'oil painting'});
    captionSearchCubit = CaptionSearchCubit(
      imageListCubit: mockImageListCubit,
    );
  });

  tearDown(() {
    captionSearchCubit.close();
  });

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ImageListCubit>.value(value: mockImageListCubit),
              BlocProvider<CaptionSearchCubit>.value(
                value: captionSearchCubit,
              ),
            ],
            child: const CaptionSearchBar(),
          ),
        ),
      ),
    );
    // Expand the search bar so the text field is visible.
    captionSearchCubit.toggleExpanded();
    await tester.pumpAndSettle();
  }

  Future<void> typeText(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('CaptionSearchBar autocomplete', () {
    testWidgets('typing ":" shows filter name suggestions', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':');

      // The 'tag' filter suggestion should be rendered in the overlay.
      expect(find.textContaining('tag —'), findsWidgets);
    });

    testWidgets('typing ":tag:" shows tag value suggestions', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:');

      expect(find.text('sunset'), findsOneWidget);
      expect(find.text('beach'), findsOneWidget);
      expect(find.text('mountain'), findsOneWidget);
    });

    testWidgets('selecting a filter name inserts ":name:" into the field', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':t');

      await tester.tap(find.textContaining('tag —').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, ':tag:');
    });

    testWidgets('selecting a tag value inserts the value into the field', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:sun');

      await tester.tap(find.text('sunset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, ':tag:sunset:');
    });

    testWidgets('pressing Escape dismisses the suggestions overlay', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:');

      expect(find.text('sunset'), findsOneWidget);

      // Escape is handled by the text field's focus node, which forwards
      // to / dismisses the overlay. Focus stays on the text field.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('sunset'), findsNothing);
    });

    testWidgets('arrow down + enter selects the highlighted suggestion', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:');

      // Suggestions render in insertion order: sunset, beach, mountain.
      expect(find.text('sunset'), findsOneWidget);
      expect(find.text('beach'), findsOneWidget);

      // Default selection is the first item (sunset). Arrow down moves to
      // the second item (beach).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Enter selects the currently highlighted suggestion.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, ':tag:beach:');
    });

    testWidgets('enter selects the first suggestion without arrow keys', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, ':tag:sunset:');
    });

    testWidgets('arrow up wraps around to the last suggestion from the first', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:');

      // Arrow up from the first item wraps to the last (mountain).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, ':tag:mountain:');
    });

    testWidgets('suggestions dismiss when search is cleared', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await typeText(tester, ':tag:');

      expect(find.text('sunset'), findsOneWidget);

      // Collapse the search bar, which clears the query. The cubit state
      // listener syncs the controller back to empty, which fires the
      // text-changed listener and dismisses the overlay.
      captionSearchCubit.toggleExpanded();
      await tester.pumpAndSettle();

      expect(find.text('sunset'), findsNothing);
    });
  });

  group('tag filter chips', () {
    testWidgets('shows a chips overlay anchored below the field when focused', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // Chips live in a Key'd overlay (not inline) so taps aren't canceled by
      // the field's focus listener unmounting them — same pattern as the
      // autocomplete overlay.
      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsOneWidget);
      expect(find.text('sunset'), findsOneWidget);
      expect(find.text('beach'), findsOneWidget);
      expect(find.text('mountain'), findsOneWidget);
    });

    testWidgets('removes the chips overlay when the search bar collapses', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsOneWidget);

      // Chips are gated on isExpanded (not focus), so collapsing dismisses.
      captionSearchCubit.toggleExpanded();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsNothing);
    });

    testWidgets('keeps the chips overlay when the field loses focus', (
      WidgetTester tester,
    ) async {
      // Regression: a focus flutter while clicking a chip must NOT tear the
      // overlay down mid-tap (that caused onTapDown -> onTapCancel). Chips
      // persist while the bar is expanded, regardless of momentary focus.
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsOneWidget);
    });

    testWidgets('hides the chips overlay while typing a structured :filter: query', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await typeText(tester, ':tag:');

      // Autocomplete owns the :filter: space; the chips overlay must yield.
      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsNothing);
    });

    testWidgets('tapping a chip injects #tag into the query', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('sunset'));
      await tester.pump();

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, '#sunset');
      // Proves the full filter wire, not just the controller text:
      // tap -> CaptionSearchCubit -> ImageListCubit.updateSearchQuery.
      verify(mockImageListCubit.updateSearchQuery('#sunset')).called(1);
    });

    testWidgets('tapping a chip on its padding (not the text) toggles', (
      WidgetTester tester,
    ) async {
      // Regression: the chip's GestureDetector must be HitTestBehavior.opaque
      // so the whole chip body is tappable. With deferToChild only the Text
      // glyphs are hit-testable, so a real click on the padding would miss.
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      // Tap inside the chip's padding, away from the '#' / label glyphs.
      final Offset topLeft =
          tester.getTopLeft(find.byKey(const Key('tagChip-sunset')));
      await tester.tapAt(topLeft + const Offset(4, 2));
      await tester.pump();

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, '#sunset');
    });

    testWidgets('tapping an active chip removes the #tag', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('sunset'));
      await tester.pump();
      await tester.tap(find.text('sunset'));
      await tester.pump();

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('multiple chips compose into space-separated hashtags', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('sunset'));
      await tester.pump();
      await tester.tap(find.text('beach'));
      await tester.pump();

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, '#sunset #beach');
    });

    testWidgets('chips compose with typed plain text', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sunset');
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('beach'));
      await tester.pump();

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, 'sunset #beach');
    });

    testWidgets('tapping a chip keeps focus so the overlay stays open', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('sunset'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Overlay still present => the field retained focus (GestureDetector
      // does not steal it, unlike InkWell). The user can keep typing/tapping.
      expect(find.byKey(const Key('tagFilterChipsOverlay')), findsOneWidget);

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(field.controller!.text, '#sunset');
    });
  });
}
