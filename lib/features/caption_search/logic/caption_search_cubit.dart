import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../image_list/logic/image_list_cubit.dart';

part 'caption_search_state.dart';

/// A Cubit that manages the UI state and business logic for the caption search bar.
///
/// This cubit handles:
/// - Expansion state of the search bar
/// - Replace mode toggle
/// - Search and replace text input
/// - Delegation to ImageListCubit for actual search/replace operations
class CaptionSearchCubit extends Cubit<CaptionSearchState> {
  /// Creates a [CaptionSearchCubit] that depends on [ImageListCubit].
  CaptionSearchCubit({required this.imageListCubit})
    : super(CaptionSearchState(
          isCaseSensitive: imageListCubit.state.caseSensitive,
        ));

  /// The ImageListCubit used for search and replace operations.
  final ImageListCubit imageListCubit;

  /// Toggles the expanded state of the search bar.
  ///
  /// When expanding, the search bar shows the text field.
  /// When collapsing, it clears all state and returns to icon-only view.
  void toggleExpanded() {
    if (state.isExpanded) {
      // Collapsing - clear everything
      emit(const CaptionSearchState());
      imageListCubit.clearSearch();
    } else {
      // Expanding
      emit(state.copyWith(isExpanded: true));
    }
  }

  /// Updates the search query text.
  ///
  /// Also updates the ImageListCubit to perform the actual filtering.
  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
    imageListCubit.updateSearchQuery(query);
  }

  /// Toggles case sensitivity for the search.
  void toggleCaseSensitive() {
    imageListCubit.toggleCaseSensitive();
    // Emit new state to trigger UI rebuild with updated case sensitivity
    emit(state.copyWith(isCaseSensitive: imageListCubit.state.caseSensitive));
  }

  /// Clears the search query and resets the search.
  void clearSearch() {
    emit(state.copyWith(searchQuery: ''));
    imageListCubit.clearSearch();
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
    imageListCubit.searchAndReplace(state.searchQuery, state.replaceText);

    // Clear search in ImageListCubit to reload full list
    imageListCubit.clearSearch();

    // Collapse the search bar
    emit(const CaptionSearchState());
  }

  /// Returns the number of filtered images based on the current search.
  int get resultCount => imageListCubit.filteredImages.length;

  /// Returns the total number of images.
  int get totalCount => imageListCubit.state.images.length;

  /// Returns whether the replace operation can be executed.
  bool get canExecuteReplace => state.replaceText.isNotEmpty;

  /// Returns whether there is an active search query.
  bool get hasActiveSearch => imageListCubit.state.searchQuery.isNotEmpty;

  /// Returns the current case sensitivity setting.
  bool get isCaseSensitive => state.isCaseSensitive;
}
