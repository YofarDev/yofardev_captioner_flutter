import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/caption_search/presentation/widgets/filter_help_dialog.dart';

// ponytail: examples in FilterHelpDialog render as RichText (TextSpan), which
// find.textContaining cannot see. Match against the flattened plain text.
Finder findRichTextContaining(String substring) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is RichText && widget.text.toPlainText().contains(substring),
);

void main() {
  // ponytail: harness opens the dialog via a button, returns a Completer so we
  // can assert what showDialog resolved with (always null since the close
  // button pops without a value).
  Future<Completer<void>> pumpAndOpen(WidgetTester tester) async {
    final Completer<void> completer = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  await FilterHelpDialog.show(context);
                  completer.complete();
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return completer;
  }

  testWidgets('renders all filter syntax rows and example queries', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(tester);

    expect(find.text('Caption Filters'), findsOneWidget);

    // Representative filter syntax rows.
    expect(find.text(':has:text:'), findsOneWidget);
    expect(find.text(':has:obj:'), findsOneWidget);
    expect(find.text(':has:bbox:'), findsOneWidget);
    expect(find.text(':dupbbox:'), findsOneWidget);
    expect(find.text(':elements:N:'), findsOneWidget);
    expect(find.text(':medium:value:'), findsOneWidget);
    expect(find.text(':nocaption:'), findsOneWidget);
    expect(find.text(':tag:value:'), findsOneWidget);
    expect(find.text(':notag:'), findsOneWidget);

    // Representative examples (rendered as RichText, so match via plain text).
    expect(findRichTextContaining('Images with text layers'), findsOneWidget);
    expect(findRichTextContaining('Uncaptioned images'), findsOneWidget);
    expect(findRichTextContaining('Untagged images'), findsOneWidget);
    // ponytail: include the query prefix to stay unique once the #favorite chip
    // example also renders "Images tagged "favorite"".
    expect(
      findRichTextContaining(':tag:favorite: — Images tagged "favorite"'),
      findsOneWidget,
    );
    expect(
      findRichTextContaining('#favorite — Images tagged'),
      findsOneWidget,
    );
  });

  testWidgets('close button dismisses the dialog and completes the future', (
    WidgetTester tester,
  ) async {
    final Completer<void> completer = await pumpAndOpen(tester);

    expect(find.text('Caption Filters'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Caption Filters'), findsNothing);
    expect(completer.isCompleted, isTrue);
  });
}
