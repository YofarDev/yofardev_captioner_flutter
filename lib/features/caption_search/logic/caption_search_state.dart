part of 'caption_search_cubit.dart';

/// The state of the caption search bar UI.
///
/// This class holds all the mutable state for the search bar widget.
class CaptionSearchState extends Equatable {
  /// Whether the search bar is expanded (showing the text field).
  final bool isExpanded;

  /// Whether the replace mode is active (showing the replace field).
  final bool showReplaceMode;

  /// The current search query text.
  final String searchQuery;

  /// The current replacement text.
  final String replaceText;

  /// Whether the search is case sensitive.
  final bool isCaseSensitive;

  const CaptionSearchState({
    this.isExpanded = false,
    this.showReplaceMode = false,
    this.searchQuery = '',
    this.replaceText = '',
    this.isCaseSensitive = false,
  });

  /// Creates a copy of this state with the given fields replaced.
  CaptionSearchState copyWith({
    bool? isExpanded,
    bool? showReplaceMode,
    String? searchQuery,
    String? replaceText,
    bool? isCaseSensitive,
  }) {
    return CaptionSearchState(
      isExpanded: isExpanded ?? this.isExpanded,
      showReplaceMode: showReplaceMode ?? this.showReplaceMode,
      searchQuery: searchQuery ?? this.searchQuery,
      replaceText: replaceText ?? this.replaceText,
      isCaseSensitive: isCaseSensitive ?? this.isCaseSensitive,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        isExpanded,
        showReplaceMode,
        searchQuery,
        replaceText,
        isCaseSensitive,
      ];
}
