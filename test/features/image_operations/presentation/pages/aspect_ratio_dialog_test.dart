import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/pages/aspect_ratio_dialog.dart';

import 'aspect_ratio_dialog_test.mocks.dart';

@GenerateNiceMocks(<MockSpec<ImageListCubit>>[MockSpec<ImageListCubit>()])
void main() {
  // ponytail: stub getAspectRatioCounts on a MockImageListCubit and supply it
  // via BlocProvider so context.read<ImageListCubit>() resolves.
  Widget harnessWithRatios(Map<String, int> counts) {
    final MockImageListCubit cubit = MockImageListCubit();
    when(cubit.getAspectRatioCounts()).thenReturn(counts);
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<ImageListCubit>.value(
          value: cubit,
          child: const AspectRatioDialog(),
        ),
      ),
    );
  }

  testWidgets('shows empty-state when no ratios are present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harnessWithRatios(<String, int>{}));
    await tester.pump();

    expect(find.text('Aspect Ratio Distribution'), findsOneWidget);
    expect(find.textContaining('Total: 0'), findsOneWidget);
    // No section headers should render when all groups are empty.
    expect(find.textContaining('Landscape'), findsNothing);
    expect(find.textContaining('Portrait'), findsNothing);
    expect(find.textContaining('Square'), findsNothing);
    expect(find.textContaining('Others'), findsNothing);
    expect(find.textContaining('Tags'), findsNothing);
  });

  testWidgets('groups landscape, portrait, square ratios and shows counts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harnessWithRatios(<String, int>{
        '16:9': 5, // landscape
        '4:3': 3, // landscape
        '9:16': 2, // portrait
        '1:1': 4, // square
      }),
    );
    await tester.pump();

    expect(find.textContaining('Total: 14'), findsOneWidget);

    // Section headers present with group totals.
    expect(find.text('Landscape (8)'), findsOneWidget);
    expect(find.text('Portrait (2)'), findsOneWidget);
    expect(find.text('Square (4)'), findsOneWidget);
    expect(find.textContaining('Others'), findsNothing); // none in this set

    // Ratio chips render with their counts.
    expect(find.text('16:9'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('4:3'), findsOneWidget);
    expect(find.text('9:16'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('4'), findsWidgets);

    // Percentages add up — 5/14 ≈ 35.7%, 4/14 ≈ 28.6%, etc.
    expect(find.textContaining('35.7%'), findsOneWidget);
    expect(find.textContaining('28.6%'), findsOneWidget);
  });

  testWidgets('routes malformed ratios to the Others group', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harnessWithRatios(<String, int>{
        'weird': 1, // unparseable
        '2:1': 2, // landscape
      }),
    );
    await tester.pump();

    expect(find.text('Landscape (2)'), findsOneWidget);
    expect(find.text('Others (1)'), findsOneWidget);
    expect(find.textContaining('Square'), findsNothing);
    expect(find.textContaining('Portrait'), findsNothing);
  });

  testWidgets('close button pops the dialog', (WidgetTester tester) async {
    await tester.pumpWidget(harnessWithRatios(<String, int>{}));
    await tester.pump();

    expect(find.text('Aspect Ratio Distribution'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Aspect Ratio Distribution'), findsNothing);
  });

  testWidgets('shows Tags section with per-tag counts when tags exist', (
    WidgetTester tester,
  ) async {
    final MockImageListCubit cubit = MockImageListCubit();
    when(cubit.getAspectRatioCounts()).thenReturn(<String, int>{'1:1': 4});
    when(cubit.getTagCounts()).thenReturn(<String, int>{
      'sketch': 3,
      'painting': 1,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<ImageListCubit>.value(
            value: cubit,
            child: const AspectRatioDialog(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Tags (4)'), findsOneWidget);
    expect(find.text('sketch (3)'), findsOneWidget);
    expect(find.text('painting (1)'), findsOneWidget);
  });
}
