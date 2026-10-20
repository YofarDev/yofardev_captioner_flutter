/// Public API of the image_operations feature.
///
/// Other features and the composition root may depend only on what this
/// barrel exports — never on feature-internal files.
library;

export 'domain/models/crop_image.dart' show CropImage;
export 'presentation/bloc/image_operations_cubit.dart'
    show ImageOperationsCubit, ImageOperationsState;
export 'presentation/pages/aspect_ratio_dialog.dart' show AspectRatioDialog;
export 'presentation/pages/convert_images_dialog.dart' show ConvertImagesDialog;
export 'presentation/pages/crop_image_screen.dart' show CropImageScreen;
export 'presentation/widgets/controls_view.dart' show ControlsView;
export 'presentation/widgets/controls_widgets.dart'
    show
        ConvertAllImagesButton,
        PickFolderButton,
        RenameAllFilesButton,
        SettingsButton;
