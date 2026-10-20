/// Public API of the main_area feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'presentation/pages/current_image_view.dart' show CurrentImageView;
export 'presentation/pages/main_area_view.dart' show MainAreaView;
export 'presentation/pages/search_and_replace_widget.dart'
    show SearchAndReplaceWidget;
