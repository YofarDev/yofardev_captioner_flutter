import '../../../structured_captioning/data/models/ideogram_caption.dart';

class BatchApplyTemplate {
  final String? highLevelDescription;
  final String? aesthetics;
  final String? lighting;
  final String? medium;
  final String? photo;
  final String? artStyle;
  final List<String>? colorPalette;
  final String? background;

  const BatchApplyTemplate({
    this.highLevelDescription,
    this.aesthetics,
    this.lighting,
    this.medium,
    this.photo,
    this.artStyle,
    this.colorPalette,
    this.background,
  });

  IdeogramCaption mergeInto(IdeogramCaption existing) {
    final IdeogramStyleDescription style = existing.styleDescription;
    final IdeogramCompositionalDeconstruction comp =
        existing.compositionalDeconstruction;

    final String resolvedMedium = medium ?? style.medium;

    return IdeogramCaption(
      highLevelDescription:
          highLevelDescription ?? existing.highLevelDescription,
      styleDescription: IdeogramStyleDescription(
        aesthetics: aesthetics ?? style.aesthetics,
        lighting: lighting ?? style.lighting,
        medium: resolvedMedium,
        photo: resolvedMedium == 'photograph' ? (photo ?? style.photo) : null,
        artStyle: resolvedMedium != 'photograph'
            ? (artStyle ?? style.artStyle)
            : null,
        colorPalette: colorPalette ?? style.colorPalette,
      ),
      compositionalDeconstruction: IdeogramCompositionalDeconstruction(
        background: background ?? comp.background,
        elements: comp.elements,
      ),
    );
  }

  IdeogramCaption toMinimalCaption() {
    final String resolvedMedium = medium ?? 'photograph';
    return IdeogramCaption(
      highLevelDescription: highLevelDescription ?? '',
      styleDescription: IdeogramStyleDescription(
        aesthetics: aesthetics ?? '',
        lighting: lighting ?? '',
        medium: resolvedMedium,
        photo: resolvedMedium == 'photograph' ? (photo ?? '') : null,
        artStyle: resolvedMedium != 'photograph' ? (artStyle ?? '') : null,
        colorPalette: colorPalette ?? <String>[],
      ),
      compositionalDeconstruction: IdeogramCompositionalDeconstruction(
        background: background ?? '',
        elements: const <IdeogramElement>[],
      ),
    );
  }
}
