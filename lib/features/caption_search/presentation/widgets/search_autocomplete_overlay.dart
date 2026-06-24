import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/autocomplete_engine.dart';

typedef _AutocompleteKeyHandler =
    KeyEventResult Function(FocusNode node, KeyEvent event);

/// Manages an [OverlayEntry] that displays autocomplete suggestions below
/// a search field via a [LayerLink]/[CompositedTransformFollower] pair.
///
/// Supports keyboard navigation (arrow up/down, enter, escape), mouse hover,
/// and grouped display with category headers when multiple suggestion types
/// are present.
///
/// Keyboard navigation requires the anchor widget to forward key events to
/// [handleKeyEvent], because the text field keeps focus while the overlay is
/// open (the standard autocomplete pattern used by [RawAutocomplete]).
class SearchAutocompleteOverlay {
  SearchAutocompleteOverlay._();

  static final Map<OverlayEntry, ValueNotifier<List<AutocompleteSuggestion>>>
  _activeNotifiers =
      <OverlayEntry, ValueNotifier<List<AutocompleteSuggestion>>>{};

  static final Map<OverlayEntry, _AutocompleteKeyHandler> _activeKeyHandlers =
      <OverlayEntry, _AutocompleteKeyHandler>{};

  /// Shows an autocomplete dropdown anchored to [target] via [link].
  ///
  /// Returns the [OverlayEntry] so callers can call [update] / [remove] later.
  static OverlayEntry show({
    required BuildContext context,
    required LayerLink link,
    required List<AutocompleteSuggestion> suggestions,
    required ValueChanged<AutocompleteSuggestion> onSelected,
    required VoidCallback onDismiss,
  }) {
    final ValueNotifier<List<AutocompleteSuggestion>> notifier =
        ValueNotifier<List<AutocompleteSuggestion>>(suggestions);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _AutocompleteDropdown(
        link: link,
        suggestionsNotifier: notifier,
        onSelected: onSelected,
        onDismiss: onDismiss,
        registerKeyHandler: (_AutocompleteKeyHandler handler) =>
            _activeKeyHandlers[entry] = handler,
        unregisterKeyHandler: () => _activeKeyHandlers.remove(entry),
      ),
    );

    _activeNotifiers[entry] = notifier;
    Overlay.of(context).insert(entry);
    return entry;
  }

  /// Replaces the suggestions shown in [entry] with [suggestions].
  static void update(
    OverlayEntry entry,
    List<AutocompleteSuggestion> suggestions,
  ) {
    final ValueNotifier<List<AutocompleteSuggestion>>? notifier =
        _activeNotifiers[entry];
    if (notifier != null) {
      notifier.value = suggestions;
    }
  }

  /// Removes the overlay entry from the overlay.
  ///
  /// Safe to call multiple times with the same entry.
  static void remove(OverlayEntry entry) {
    if (!_activeNotifiers.containsKey(entry)) return;
    _activeNotifiers.remove(entry);
    _activeKeyHandlers.remove(entry);
    entry.remove();
  }

  /// Forwards a key event to the dropdown for [entry].
  ///
  /// The anchor widget (e.g. the search text field) should call this from its
  /// focus node's `onKeyEvent` for ArrowUp/ArrowDown/Enter so the overlay can
  /// navigate/select while focus stays on the text field. Returns
  /// [KeyEventResult.handled] when the dropdown consumed the event, otherwise
  /// [KeyEventResult.ignored].
  static KeyEventResult handleKeyEvent(
    OverlayEntry entry,
    FocusNode node,
    KeyEvent event,
  ) {
    final _AutocompleteKeyHandler? handler = _activeKeyHandlers[entry];
    if (handler != null) {
      return handler(node, event);
    }
    return KeyEventResult.ignored;
  }
}

// ---------------------------------------------------------------------------
// Internal display helpers
// ---------------------------------------------------------------------------

sealed class _DisplayItem {
  const _DisplayItem();
}

class _HeaderItem extends _DisplayItem {
  const _HeaderItem(this.text);
  final String text;
}

class _SuggestionItem extends _DisplayItem {
  const _SuggestionItem(this.suggestion, this.index);
  final AutocompleteSuggestion suggestion;
  final int index; // index into the original suggestions list
}

class _SuggestionGroup {
  const _SuggestionGroup({required this.header, required this.items});

  final String header;
  final List<AutocompleteSuggestion> items;
}

IconData _iconForType(AutocompleteSuggestion suggestion) {
  return switch (suggestion) {
    FilterNameSuggestion _ => Icons.filter_list,
    TagValueSuggestion _ => Icons.label,
    HasTypeSuggestion _ => Icons.category,
    MediumValueSuggestion _ => Icons.brush,
  };
}

String _labelFor(AutocompleteSuggestion suggestion) {
  return switch (suggestion) {
    FilterNameSuggestion(:final String name, :final String description) =>
      '$name — $description',
    TagValueSuggestion(:final String value) => value,
    HasTypeSuggestion(:final String type) => type,
    MediumValueSuggestion(:final String value) => value,
  };
}

List<_SuggestionGroup> _groupByType(List<AutocompleteSuggestion> suggestions) {
  if (suggestions.isEmpty) return <_SuggestionGroup>[];

  final Map<Type, List<AutocompleteSuggestion>> grouped =
      <Type, List<AutocompleteSuggestion>>{};
  for (final AutocompleteSuggestion s in suggestions) {
    grouped.putIfAbsent(s.runtimeType, () => <AutocompleteSuggestion>[]).add(s);
  }

  return grouped.entries.map((MapEntry<Type, List<AutocompleteSuggestion>> e) {
    final String header = switch (e.key) {
      FilterNameSuggestion _ => 'Filters',
      TagValueSuggestion _ => 'Tags',
      HasTypeSuggestion _ => 'Types',
      MediumValueSuggestion _ => 'Mediums',
      _ => 'Suggestions',
    };
    return _SuggestionGroup(header: header, items: e.value);
  }).toList();
}

List<_DisplayItem> _buildDisplayList(List<AutocompleteSuggestion> suggestions) {
  final List<_SuggestionGroup> groups = _groupByType(suggestions);
  final bool showHeaders = groups.length > 1;
  final List<_DisplayItem> items = <_DisplayItem>[];
  int suggestionIndex = 0;

  for (final _SuggestionGroup group in groups) {
    if (showHeaders) {
      items.add(_HeaderItem(group.header));
    }
    for (final AutocompleteSuggestion s in group.items) {
      items.add(_SuggestionItem(s, suggestionIndex));
      suggestionIndex++;
    }
  }

  return items;
}

// ---------------------------------------------------------------------------
// Dropdown stateful widget
// ---------------------------------------------------------------------------

class _AutocompleteDropdown extends StatefulWidget {
  const _AutocompleteDropdown({
    required this.link,
    required this.suggestionsNotifier,
    required this.onSelected,
    required this.onDismiss,
    required this.registerKeyHandler,
    required this.unregisterKeyHandler,
  });

  final LayerLink link;
  final ValueNotifier<List<AutocompleteSuggestion>> suggestionsNotifier;
  final ValueChanged<AutocompleteSuggestion> onSelected;
  final VoidCallback onDismiss;
  final void Function(_AutocompleteKeyHandler handler) registerKeyHandler;
  final VoidCallback unregisterKeyHandler;

  @override
  State<_AutocompleteDropdown> createState() => _AutocompleteDropdownState();
}

class _AutocompleteDropdownState extends State<_AutocompleteDropdown> {
  int _selectedIndex = 0;
  int? _hoveredIndex;
  late List<AutocompleteSuggestion> _suggestions;
  late List<_DisplayItem> _displayItems;

  @override
  void initState() {
    super.initState();
    _suggestions = widget.suggestionsNotifier.value;
    _displayItems = _buildDisplayList(_suggestions);
    widget.suggestionsNotifier.addListener(_onSuggestionsChanged);
    widget.registerKeyHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    widget.unregisterKeyHandler();
    widget.suggestionsNotifier.removeListener(_onSuggestionsChanged);
    super.dispose();
  }

  void _onSuggestionsChanged() {
    setState(() {
      _suggestions = widget.suggestionsNotifier.value;
      _displayItems = _buildDisplayList(_suggestions);
      if (_suggestions.isEmpty) {
        _selectedIndex = 0;
      } else {
        _selectedIndex = _selectedIndex.clamp(0, _suggestions.length - 1);
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_suggestions.isEmpty) return KeyEventResult.ignored;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
        });
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex =
              (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
        });
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
          widget.onSelected(_suggestions[_selectedIndex]);
        }
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onDismiss();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return CompositedTransformFollower(
      link: widget.link,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 4),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: darkGrey,
        child: Focus(
          onKeyEvent: _handleKeyEvent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _displayItems.length,
              itemBuilder: (BuildContext context, int index) {
                final _DisplayItem item = _displayItems[index];
                return switch (item) {
                  _HeaderItem(:final String text) => _buildHeader(text),
                  _SuggestionItem(
                    :final AutocompleteSuggestion suggestion,
                    :final int index,
                  ) =>
                    _buildSuggestionItem(suggestion, index),
                };
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 11,
          color: lightPink,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(AutocompleteSuggestion suggestion, int index) {
    final bool isSelected = index == _selectedIndex;
    final bool isHovered = index == _hoveredIndex;

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = lightPink.withValues(alpha: 0.2);
    } else if (isHovered) {
      backgroundColor = Colors.white.withValues(alpha: 0.05);
    } else {
      backgroundColor = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (PointerEnterEvent _) {
        setState(() {
          _hoveredIndex = index;
        });
      },
      onExit: (PointerExitEvent _) {
        setState(() {
          _hoveredIndex = null;
        });
      },
      child: GestureDetector(
        onTap: () => widget.onSelected(suggestion),
        child: Container(
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(_iconForType(suggestion), size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _labelFor(suggestion),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
