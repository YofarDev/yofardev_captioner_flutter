import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../image_list/domain/services/caption_session_service.dart';

part 'caption_search_state.dart';

/// A Cubit that manages the UI state and business logic for the caption search bar.
///
/// This cubit handles:
/// - Expansion state of the search bar
/// - Replace mode toggle
/// - Search and replace text input
/// - Delegation to CaptionSessionService for actual search/replace operations
class CaptionSearchCubit extends Cubit<CaptionSearchState> {
  /// Creates a [CaptionSearchCubit] that depends on [CaptionSessionService].
  CaptionSearchCubit({required CaptionSessionService session})
    : _session = session,
      super(CaptionSearchState(isCaseSensitive: session.state.caseSensitive));

  /// The session used for search and replace operations.
  final CaptionSessionService _session;

  /// Toggles the expanded state of the search bar.
  ///
  /// When expanding, the search bar shows the text field.
  /// When collapsing, it clears all state and returns to icon-only view.
  void toggleExpanded() {
    if (state.isExpanded) {
      // Collapsing - clear everything
      emit(const CaptionSearchState());
      _session.clearSearch();
    } else {
      // Expanding
      emit(state.copyWith(isExpanded: true));
    }
  }

  /// Updates the search query text.
  ///
  /// Also updates the session to perform the actual filtering.
  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
    _session.updateSearchQuery(query);
  }

  /// Toggles case sensitivity for the search.
  void toggleCaseSensitive() {
    _session.toggleCaseSensitive();
    // Emit new state to trigger UI rebuild with updated case sensitivity
    emit(state.copyWith(isCaseSensitive: _session.state.caseSensitive));
  }

  /// Clears the search query and resets the search.
  void clearSearch() {
    emit(state.copyWith(searchQuery: ''));
    _session.clearSearch();
  }

  /// Toggles the replace mode on/off.
  ///
  /// When disabling, also clears the replace text.
  void toggleReplaceMode() {
    if (state.showReplaceMode) {
      emit(state.copyWith(showReplaceMode: false, replaceText: ''));
    } else {
      emit(state.copyWith(showReplaceMode: true));
    }
  }

  /// Updates the replacement text.
  void updateReplaceText(String text) {
    emit(state.copyWith(replaceText: text));
  }

  /// Executes the search and replace operation.
  ///
  /// Replaces all occurrences of [searchQuery] with [replaceText]
  /// across all image captions, then collapses the search bar.
  Future<void> executeReplace() async {
    if (state.searchQuery.isEmpty) return;

    // Perform the replace operation
    _session.searchAndReplace(state.searchQuery, state.replaceText);

    // Clear the session's search to reload the full list
    _session.clearSearch();

    // Collapse the search bar
    emit(const CaptionSearchState());
  }

  /// Returns the number of filtered images based on the current search.
  int get resultCount => _session.current.filteredImages.length;

  /// Returns the total number of images.
  int get totalCount => _session.state.images.length;

  /// Returns whether the replace operation can be executed.
  bool get canExecuteReplace => state.replaceText.isNotEmpty;

  /// Returns whether there is an active search query.
  bool get hasActiveSearch => _session.state.searchQuery.isNotEmpty;

  /// Returns the current case sensitivity setting.
  bool get isCaseSensitive => state.isCaseSensitive;
}
