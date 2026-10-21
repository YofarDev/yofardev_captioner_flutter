import 'package:equatable/equatable.dart';

import '../../../../core/models/app_image.dart';
import '../models/image_list_state.dart';

/// Immutable point-in-time view of one caption session: the raw
/// [ImageListState] plus the derived views (filtering, current selection)
/// consumers need, so they never have to recompute filtering themselves.
class CaptionSessionSnapshot extends Equatable {
  const CaptionSessionSnapshot({
    required this.state,
    required this.filteredImages,
    required this.displayedImages,
    required this.currentDisplayedImage,
  });

  /// The full session state (images, categories, search, guidance, ...).
  final ImageListState state;

  /// Images matching the current search query/filter.
  final List<AppImage> filteredImages;

  /// What should be displayed; currently identical to [filteredImages].
  final List<AppImage> displayedImages;

  /// The currently displayed image (see
  /// `CaptionSessionService.currentDisplayedImage` semantics).
  final AppImage? currentDisplayedImage;

  @override
  List<Object?> get props => <Object?>[state];
}
