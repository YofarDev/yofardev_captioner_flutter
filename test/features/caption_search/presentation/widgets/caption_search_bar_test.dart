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
  group('CaptionSearchBar autocomplete', () {
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

    testWidgets(
      'arrow up wraps around to the last suggestion from the first',
      (WidgetTester tester) async {
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
      },
    );

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
}
