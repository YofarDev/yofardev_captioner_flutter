import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../data/services/autocomplete_engine.dart';
import '../../logic/caption_search_cubit.dart';
import 'filter_help_dialog.dart';
import 'search_autocomplete_overlay.dart';

/// A search bar widget for filtering and replacing text in image captions.
///
/// Features:
/// - Expandable search field with real-time filtering
/// - Case sensitivity toggle
/// - Replace mode with a second text field
/// - Result count display
/// - Keyboard shortcuts (Enter to execute replace)
class CaptionSearchBar extends StatefulWidget {
  const CaptionSearchBar({super.key});

  @override
  State<CaptionSearchBar> createState() => _CaptionSearchBarState();
}

class _CaptionSearchBarState extends State<CaptionSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  AutocompleteEngine? _autocompleteEngine;
  OverlayEntry? _suggestionsOverlay;

  static const Duration _animationDuration = Duration(milliseconds: 200);
  static const double _searchBarWidth = 250.0;
  static const double _replaceBarWidth = 400.0;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _setupReplaceControllerListener();
    _setupCubitStateListener();
    _setupKeyHandler();
    _textController.addListener(_onTextChangedForAutocomplete);
  }

  void _setupKeyHandler() {
    _focusNode.onKeyEvent = (FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent || _suggestionsOverlay == null) {
        return KeyEventResult.ignored;
      }
      final LogicalKeyboardKey key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape) {
        _dismissSuggestions();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.enter) {
        return SearchAutocompleteOverlay.handleKeyEvent(
          _suggestionsOverlay!,
          node,
          event,
        );
      }
      return KeyEventResult.ignored;
    };
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _widthAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  void _setupReplaceControllerListener() {
    _replaceController.addListener(() {
      final CaptionSearchCubit cubit = context.read<CaptionSearchCubit>();
      if (cubit.state.showReplaceMode) {
        cubit.updateReplaceText(_replaceController.text);
      }
    });
  }

  void _setupCubitStateListener() {
    context.read<CaptionSearchCubit>().stream.listen((
      CaptionSearchState state,
    ) {
      _syncControllersWithState(state);
    });
  }

  void _syncControllersWithState(CaptionSearchState state) {
    if (_textController.text != state.searchQuery) {
      _textController.value = TextEditingValue(text: state.searchQuery);
    }
    if (_replaceController.text != state.replaceText) {
      _replaceController.value = TextEditingValue(text: state.replaceText);
    }
  }

  @override
  void dispose() {
    _dismissSuggestions();
    _textController.removeListener(_onTextChangedForAutocomplete);
    _animationController.dispose();
    _textController.dispose();
    _replaceController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchChange(String query) {
    context.read<CaptionSearchCubit>().updateSearchQuery(query);
  }

  void _ensureAutocompleteEngine() {
    if (_autocompleteEngine != null) return;
    final ImageListCubit imageListCubit = context.read<ImageListCubit>();
    _autocompleteEngine = AutocompleteEngine(
      getUniqueTags: () => imageListCubit.getAllUniqueTags(),
      getUniqueMediums: () => imageListCubit.getAllUniqueMediums(),
    );
  }

  void _onTextChangedForAutocomplete() {
    _ensureAutocompleteEngine();

    final String text = _textController.text;
    final int cursorPos = _textController.selection.baseOffset;

    if (cursorPos < 0) {
      _dismissSuggestions();
      return;
    }

    final List<AutocompleteSuggestion> suggestions = _autocompleteEngine!
        .getSuggestions(text, cursorPos);

    if (suggestions.isEmpty) {
      _dismissSuggestions();
      return;
    }

    _showSuggestions(suggestions);
  }

  void _showSuggestions(List<AutocompleteSuggestion> suggestions) {
    if (_suggestionsOverlay != null) {
      SearchAutocompleteOverlay.update(_suggestionsOverlay!, suggestions);
      return;
    }

    _suggestionsOverlay = SearchAutocompleteOverlay.show(
      context: context,
      link: _layerLink,
      suggestions: suggestions,
      onSelected: _onSuggestionSelected,
      onDismiss: _dismissSuggestions,
    );
  }

  void _dismissSuggestions() {
    if (_suggestionsOverlay != null) {
      SearchAutocompleteOverlay.remove(_suggestionsOverlay!);
      _suggestionsOverlay = null;
    }
  }

  void _onSuggestionSelected(AutocompleteSuggestion suggestion) {
    final String text = _textController.text;
    final int cursorPos = _textController.selection.baseOffset;
    if (cursorPos < 0) return;
    final String beforeCursor = text.substring(0, cursorPos);
    final String afterCursor = text.substring(cursorPos);

    String newText;
    int newCursorPos;

    if (suggestion is FilterNameSuggestion) {
      final int lastColon = beforeCursor.lastIndexOf(':');
      newText =
          '${beforeCursor.substring(0, lastColon)}:${suggestion.name}:$afterCursor';
      newCursorPos = lastColon + suggestion.name.length + 2;
    } else if (suggestion is TagValueSuggestion) {
      const String tagPrefix = ':tag:';
      final int tagStart = beforeCursor.lastIndexOf(tagPrefix);
      newText =
          '${beforeCursor.substring(0, tagStart)}$tagPrefix${suggestion.value}:$afterCursor';
      newCursorPos = tagStart + tagPrefix.length + suggestion.value.length + 1;
    } else if (suggestion is HasTypeSuggestion) {
      const String hasPrefix = ':has:';
      final int hasStart = beforeCursor.lastIndexOf(hasPrefix);
      newText =
          '${beforeCursor.substring(0, hasStart)}$hasPrefix${suggestion.type}:$afterCursor';
      newCursorPos = hasStart + hasPrefix.length + suggestion.type.length + 1;
    } else if (suggestion is MediumValueSuggestion) {
      const String mediumPrefix = ':medium:';
      final int mediumStart = beforeCursor.lastIndexOf(mediumPrefix);
      newText =
          '${beforeCursor.substring(0, mediumStart)}$mediumPrefix${suggestion.value}:$afterCursor';
      newCursorPos =
          mediumStart + mediumPrefix.length + suggestion.value.length + 1;
    } else {
      return;
    }

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    _handleSearchChange(newText);

    _dismissSuggestions();

    _focusNode.requestFocus();
  }

  void _handleReplaceSubmitted(String text) {
    if (text.isNotEmpty) {
      context.read<CaptionSearchCubit>().executeReplace();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CaptionSearchCubit, CaptionSearchState>(
      listenWhen: (CaptionSearchState previous, CaptionSearchState current) =>
          previous.isExpanded != current.isExpanded,
      listener: (BuildContext context, CaptionSearchState state) =>
          _handleExpansionChange(state),
      child: BlocBuilder<CaptionSearchCubit, CaptionSearchState>(
        builder: (BuildContext context, CaptionSearchState state) {
          final CaptionSearchCubit cubit = context.read<CaptionSearchCubit>();
          final bool showActions =
              cubit.hasActiveSearch && !state.showReplaceMode;

          return _buildContainer(cubit, state, showActions);
        },
      ),
    );
  }

  void _handleExpansionChange(CaptionSearchState state) {
    if (state.isExpanded) {
      _animationController.forward();
      _focusNode.requestFocus();
    } else {
      _animationController.reverse();
      _focusNode.unfocus();
    }
  }

  Widget _buildContainer(
    CaptionSearchCubit cubit,
    CaptionSearchState state,
    bool showActions,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildToggleButton(cubit, state),
        _buildAnimatedContent(cubit, state, showActions),
      ],
    );
  }

  Widget _buildToggleButton(
    CaptionSearchCubit cubit,
    CaptionSearchState state,
  ) {
    return Tooltip(
      message: state.isExpanded ? 'Clear search' : 'Search captions',
      child: IconButton(
        onPressed: cubit.toggleExpanded,
        icon: Icon(
          state.isExpanded ? Icons.close : Icons.search,
          size: 18,
          color: Colors.grey[400],
        ),
        splashRadius: 20,
      ),
    );
  }

  Widget _buildAnimatedContent(
    CaptionSearchCubit cubit,
    CaptionSearchState state,
    bool showActions,
  ) {
    return SizeTransition(
      axis: Axis.horizontal,
      alignment: Alignment.topCenter,
      sizeFactor: _widthAnimation,
      child: SizedBox(
        width: state.showReplaceMode ? _replaceBarWidth : _searchBarWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _buildSearchRow(cubit, state, showActions),
            if (state.showReplaceMode) _buildReplaceRow(cubit),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow(
    CaptionSearchCubit cubit,
    CaptionSearchState state,
    bool showActions,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(width: 4),
        Expanded(child: _buildSearchTextField(cubit)),
        _buildHelpButton(),
        _buildCaseSensitiveButton(cubit),
        if (showActions) ...<Widget>[
          _buildReplaceToggleButton(cubit, state),
          // _buildClearButton(cubit),
          _buildResultCount(cubit),
        ],
      ],
    );
  }

  Widget _buildSearchTextField(CaptionSearchCubit cubit) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        onChanged: _handleSearchChange,
        decoration: InputDecoration(
          hintText: 'Search in captions...',
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildHelpButton() {
    return Tooltip(
      message: 'Filter syntax help',
      child: IconButton(
        onPressed: () => FilterHelpDialog.show(context),
        icon: Icon(Icons.help_outline, size: 16, color: Colors.grey[500]),
        splashRadius: 18,
      ),
    );
  }

  Widget _buildCaseSensitiveButton(CaptionSearchCubit cubit) {
    final bool isCaseSensitive = cubit.isCaseSensitive;
    return Tooltip(
      message: isCaseSensitive ? 'Case sensitive: ON' : 'Case sensitive: OFF',
      child: _ActionButton(
        icon: isCaseSensitive ? Icons.text_fields : Icons.text_fields_outlined,
        isActive: isCaseSensitive,
        onPressed: cubit.toggleCaseSensitive,
      ),
    );
  }

  Widget _buildReplaceToggleButton(
    CaptionSearchCubit cubit,
    CaptionSearchState state,
  ) {
    return Tooltip(
      message: 'Toggle replace mode',
      child: _ActionButton(
        icon: state.showReplaceMode ? Icons.arrow_upward : Icons.swap_horiz,
        isActive: state.showReplaceMode,
        onPressed: cubit.toggleReplaceMode,
      ),
    );
  }

  // Widget _buildClearButton(CaptionSearchCubit cubit) {
  //   return Tooltip(
  //     message: 'Clear search',
  //     child: IconButton(
  //       onPressed: cubit.toggleExpanded,
  //       icon: Icon(Icons.close, size: 16, color: Colors.grey[500]),
  //       splashRadius: 18,
  //     ),
  //   );
  // }

  Widget _buildResultCount(CaptionSearchCubit cubit) {
    final int resultCount = cubit.resultCount;
    final int totalCount = cubit.totalCount;
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 4),
      child: Text(
        '$resultCount/$totalCount',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildReplaceRow(CaptionSearchCubit cubit) {
    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeInOut,
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: _buildReplaceTextField(cubit)),
          _buildCancelButton(cubit),
          _buildExecuteReplaceButton(cubit),
        ],
      ),
    );
  }

  Widget _buildReplaceTextField(CaptionSearchCubit cubit) {
    return TextField(
      controller: _replaceController,
      onChanged: cubit.updateReplaceText,
      onSubmitted: _handleReplaceSubmitted,
      decoration: InputDecoration(
        hintText: 'Replace with...',
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildCancelButton(CaptionSearchCubit cubit) {
    return Tooltip(
      message: 'Cancel',
      child: IconButton(
        onPressed: cubit.toggleReplaceMode,
        icon: Icon(Icons.close, size: 16, color: Colors.grey[500]),
        splashRadius: 18,
      ),
    );
  }

  Widget _buildExecuteReplaceButton(CaptionSearchCubit cubit) {
    return Tooltip(
      message: 'Replace all occurrences',
      child: IconButton(
        onPressed: cubit.canExecuteReplace ? cubit.executeReplace : null,
        icon: Icon(
          Icons.done,
          size: 16,
          color: cubit.canExecuteReplace ? Colors.green[400] : Colors.grey[700],
        ),
        splashRadius: 18,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '',
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 16,
          color: isActive ? lightPink : Colors.grey[600],
        ),
        splashRadius: 18,
      ),
    );
  }
}
