import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/constants/app_colors.dart';
import 'package:yofardev_captioner/features/caption_search/data/services/autocomplete_engine.dart';
import 'package:yofardev_captioner/features/caption_search/presentation/widgets/search_autocomplete_overlay.dart';

/// Test harness that renders a [CompositedTransformTarget] for the overlay
/// to anchor to. It does NOT remove the overlay entry in its dispose;
/// the framework handles cleanup so that test-level [remove] calls don't
/// collide.
class _TestHarness extends StatefulWidget {
  const _TestHarness({
    required this.createOverlay,
  });

  final void Function(BuildContext context, LayerLink link) createOverlay;

  @override
  State<_TestHarness> createState() => _TestHarnessState();
}

class _TestHarnessState extends State<_TestHarness> {
  final LayerLink _link = LayerLink();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      widget.createOverlay(context, _link);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: const SizedBox(width: 300, height: 48, key: Key('anchor')),
    );
  }
}

/// Helper to pump a test app with an overlay showing the given [suggestions].
/// Returns the created [OverlayEntry].
Future<OverlayEntry> _pumpOverlay(
  WidgetTester tester, {
  required List<AutocompleteSuggestion> suggestions,
  ValueChanged<AutocompleteSuggestion>? onSelected,
  VoidCallback? onDismiss,
}) async {
  OverlayEntry? entry;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _TestHarness(
          createOverlay: (BuildContext ctx, LayerLink link) {
            entry = SearchAutocompleteOverlay.show(
              context: ctx,
              link: link,
              suggestions: suggestions,
              onSelected: onSelected ?? (AutocompleteSuggestion _) {},
              onDismiss: onDismiss ?? () {},
            );
          },
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return entry!;
}

/// Renders an anchor with a [FocusNode] that forwards key events to the
/// overlay via [SearchAutocompleteOverlay.handleKeyEvent] — exactly how
/// [CaptionSearchBar] drives the overlay while keeping focus on its text
/// field. The focus node auto-focuses so that [WidgetTester.sendKeyEvent]
/// events reach the handler.
class _KeyDrivenHarness extends StatefulWidget {
  const _KeyDrivenHarness({
    required this.suggestions,
    required this.onSelected,
    required this.onDismiss,
  });

  final List<AutocompleteSuggestion> suggestions;
  final ValueChanged<AutocompleteSuggestion> onSelected;
  final VoidCallback onDismiss;

  @override
  State<_KeyDrivenHarness> createState() => _KeyDrivenHarnessState();
}

class _KeyDrivenHarnessState extends State<_KeyDrivenHarness> {
  final LayerLink _link = LayerLink();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (FocusNode node, KeyEvent event) {
      final OverlayEntry? entry = _entry;
      if (entry == null) return KeyEventResult.ignored;
      return SearchAutocompleteOverlay.handleKeyEvent(entry, node, event);
    };
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      setState(() {
        _entry = SearchAutocompleteOverlay.show(
          context: context,
          link: _link,
          suggestions: widget.suggestions,
          onSelected: widget.onSelected,
          onDismiss: widget.onDismiss,
        );
      });
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    if (_entry != null) SearchAutocompleteOverlay.remove(_entry!);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: const SizedBox(width: 100, height: 40),
      ),
    );
  }
}

/// Pumps the key-driven harness inside a [MaterialApp] (which provides the
/// [Overlay] the overlay entry mounts into) and settles a frame.
Future<void> _pumpKeyDrivenHarness(
  WidgetTester tester, {
  required List<AutocompleteSuggestion> suggestions,
  required ValueChanged<AutocompleteSuggestion> onSelected,
  required VoidCallback onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: _KeyDrivenHarness(
            suggestions: suggestions,
            onSelected: onSelected,
            onDismiss: onDismiss,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('SearchAutocompleteOverlay', () {
    // -----------------------------------------------------------------------
    // show
    // -----------------------------------------------------------------------

    testWidgets('show returns a mounted OverlayEntry', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          FilterNameSuggestion(name: 'tag', description: 'Filter by tag'),
        ],
      );

      expect(entry, isNotNull);
      expect(entry.mounted, isTrue);

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('show renders suggestion labels in the overlay', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          FilterNameSuggestion(name: 'tag', description: 'Filter by tag'),
          TagValueSuggestion(value: 'sunset'),
        ],
      );

      expect(find.text('tag — Filter by tag'), findsOneWidget);
      expect(find.text('sunset'), findsOneWidget);

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('show renders correct icons per suggestion type', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          FilterNameSuggestion(name: 'tag', description: 'Filter by tag'),
          TagValueSuggestion(value: 'sunset'),
          HasTypeSuggestion(type: 'bbox'),
          MediumValueSuggestion(value: 'photograph'),
        ],
      );

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.label), findsOneWidget);
      expect(find.byIcon(Icons.category), findsOneWidget);
      expect(find.byIcon(Icons.brush), findsOneWidget);

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('show renders category headers for mixed types', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          FilterNameSuggestion(name: 'tag', description: 'Filter by tag'),
          TagValueSuggestion(value: 'sunset'),
        ],
      );

      // Verify headers rendered via their unique padding
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Padding &&
              w.padding == const EdgeInsets.fromLTRB(12, 8, 12, 4),
        ),
        findsNWidgets(2),
      );

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('show does not render headers for single type', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          FilterNameSuggestion(name: 'tag', description: 'Filter by tag'),
          FilterNameSuggestion(name: 'has', description: 'Has element type'),
        ],
      );

      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Text && w.data == 'Filters',
        ),
        findsNothing,
      );

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('show with empty suggestions returns a mounted entry', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[],
      );

      expect(entry, isNotNull);
      expect(entry.mounted, isTrue);

      SearchAutocompleteOverlay.remove(entry);
    });

    // -----------------------------------------------------------------------
    // remove
    // -----------------------------------------------------------------------

    testWidgets('remove unmounts the overlay entry', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'beach'),
        ],
      );

      expect(find.text('beach'), findsOneWidget);

      SearchAutocompleteOverlay.remove(entry);
      await tester.pump();
      await tester.pump();

      expect(find.text('beach'), findsNothing);
    });

    testWidgets('multiple removes are safe', (WidgetTester tester) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'safe'),
        ],
      );

      SearchAutocompleteOverlay.remove(entry);
      // Second remove should not throw
      SearchAutocompleteOverlay.remove(entry);

      await tester.pump();
      // No crash
    });

    // -----------------------------------------------------------------------
    // update
    // -----------------------------------------------------------------------

    testWidgets('update replaces displayed suggestions', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          FilterNameSuggestion(name: 'tag', description: 'Filter by tag'),
          FilterNameSuggestion(name: 'has', description: 'Has element type'),
        ],
      );

      expect(find.text('tag — Filter by tag'), findsOneWidget);
      expect(find.text('has — Has element type'), findsOneWidget);

      SearchAutocompleteOverlay.update(
        entry,
        <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'mountain'),
          TagValueSuggestion(value: 'ocean'),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('tag — Filter by tag'), findsNothing);
      expect(find.text('has — Has element type'), findsNothing);
      expect(find.text('mountain'), findsOneWidget);
      expect(find.text('ocean'), findsOneWidget);

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('updating with empty list clears content', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'remove-me'),
        ],
      );

      expect(find.text('remove-me'), findsOneWidget);

      SearchAutocompleteOverlay.update(entry, <AutocompleteSuggestion>[]);
      await tester.pump();
      await tester.pump();

      expect(find.text('remove-me'), findsNothing);

      SearchAutocompleteOverlay.remove(entry);
    });

    // -----------------------------------------------------------------------
    // selection
    // -----------------------------------------------------------------------

    testWidgets('tap on suggestion calls onSelected', (
      WidgetTester tester,
    ) async {
      AutocompleteSuggestion? selectedSuggestion;
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'forest'),
          TagValueSuggestion(value: 'river'),
        ],
        onSelected: (AutocompleteSuggestion s) {
          selectedSuggestion = s;
        },
      );

      await tester.tap(find.text('river'));
      await tester.pump();

      expect(selectedSuggestion, isNotNull);
      expect(selectedSuggestion, isA<TagValueSuggestion>());
      expect((selectedSuggestion! as TagValueSuggestion).value, 'river');

      SearchAutocompleteOverlay.remove(entry);
    });

    // -----------------------------------------------------------------------
    // keyboard navigation (via handleKeyEvent forwarding)
    // -----------------------------------------------------------------------

    testWidgets('arrow down + enter selects the highlighted suggestion', (
      WidgetTester tester,
    ) async {
      AutocompleteSuggestion? selected;
      await _pumpKeyDrivenHarness(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'first'),
          TagValueSuggestion(value: 'second'),
        ],
        onSelected: (AutocompleteSuggestion s) => selected = s,
        onDismiss: () {},
      );

      // Default selection is 'first'. Arrow down moves to 'second'.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, isA<TagValueSuggestion>());
      expect((selected! as TagValueSuggestion).value, 'second');
    });

    testWidgets('enter selects the first suggestion without arrow keys', (
      WidgetTester tester,
    ) async {
      AutocompleteSuggestion? selected;
      await _pumpKeyDrivenHarness(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'first'),
          TagValueSuggestion(value: 'second'),
        ],
        onSelected: (AutocompleteSuggestion s) => selected = s,
        onDismiss: () {},
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, isA<TagValueSuggestion>());
      expect((selected! as TagValueSuggestion).value, 'first');
    });

    testWidgets('arrow up wraps around to the last suggestion', (
      WidgetTester tester,
    ) async {
      AutocompleteSuggestion? selected;
      await _pumpKeyDrivenHarness(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'first'),
          TagValueSuggestion(value: 'second'),
          TagValueSuggestion(value: 'third'),
        ],
        onSelected: (AutocompleteSuggestion s) => selected = s,
        onDismiss: () {},
      );

      // Arrow up from the first item wraps to the last (third).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(selected, isA<TagValueSuggestion>());
      expect((selected! as TagValueSuggestion).value, 'third');
    });

    testWidgets('escape calls onDismiss', (WidgetTester tester) async {
      bool dismissed = false;
      await _pumpKeyDrivenHarness(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'first'),
        ],
        onSelected: (AutocompleteSuggestion _) {},
        onDismiss: () => dismissed = true,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('handleKeyEvent ignores non-navigation keys', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'first'),
        ],
      );
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);

      // A regular letter key should not be consumed by the overlay.
      final KeyEventResult result = SearchAutocompleteOverlay.handleKeyEvent(
        entry,
        node,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
      );

      expect(result, KeyEventResult.ignored);

      SearchAutocompleteOverlay.remove(entry);
    });

    // -----------------------------------------------------------------------
    // Material appearance
    // -----------------------------------------------------------------------

    testWidgets('overlay has darkGrey background and rounded corners', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          TagValueSuggestion(value: 'style-test'),
        ],
      );

      // Find the Material that is the direct child of CompositedTransformFollower
      final Iterable<Widget> materials = find
          .byWidgetPredicate(
            (Widget w) =>
                w is Material &&
                w.color == darkGrey &&
                w.elevation == 8,
          )
          .evaluate()
          .map((Element e) => e.widget);

      expect(materials, isNotEmpty);

      final Material material = materials.first as Material;
      expect(material.color, darkGrey);
      expect(material.elevation, 8);
      expect(material.borderRadius, BorderRadius.circular(8));

      SearchAutocompleteOverlay.remove(entry);
    });

    testWidgets('overlay has max height constraint for scrollable list', (
      WidgetTester tester,
    ) async {
      final OverlayEntry entry = await _pumpOverlay(
        tester,
        suggestions: <AutocompleteSuggestion>[
          for (int i = 0; i < 20; i++) TagValueSuggestion(value: 'item $i'),
        ],
      );

      // The ConstrainedBox with maxHeight: 320 wraps the ListView
      final Iterable<ConstrainedBox> boxes = find
          .byWidgetPredicate(
            (Widget w) =>
                w is ConstrainedBox &&
                w.constraints.maxHeight == 320,
          )
          .evaluate()
          .map((Element e) => e.widget as ConstrainedBox);

      expect(boxes, isNotEmpty);
      expect(boxes.first.constraints.maxHeight, 320);

      // All items rendered (ListView builds them into the element tree)
      expect(find.textContaining('item'), findsWidgets);

      SearchAutocompleteOverlay.remove(entry);
    });
  });
}
