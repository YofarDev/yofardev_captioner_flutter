import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart';
import 'package:yofardev_captioner/core/widgets/rive_animations.dart';

/// The polish animations must load their .riv asset and reach RiveLoaded —
/// a silent RiveFailed would render as an invisible box, so assert on the
/// RiveWidget itself appearing in the tree.
void main() {
  Future<void> pumpUntilLoaded(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(RiveWidget).evaluate().isNotEmpty) {
        return;
      }
    }
  }

  testWidgets('RiveProcessingIndicator loads its rive asset', (
    WidgetTester tester,
  ) async {
    await pumpUntilLoaded(tester, const RiveProcessingIndicator(size: 32));
    expect(find.byType(RiveWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RiveDropHint loads its rive asset', (WidgetTester tester) async {
    await pumpUntilLoaded(tester, const RiveDropHint());
    expect(find.byType(RiveWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RiveEmptyStateHero loads its rive asset', (
    WidgetTester tester,
  ) async {
    await pumpUntilLoaded(tester, const RiveEmptyStateHero());
    expect(find.byType(RiveWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
