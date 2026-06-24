import '../../../llm_config/data/models/structured_batch_overrides.dart';
import 'ideogram_caption.dart';

/// Returns [caption] with any enabled [overrides] applied.
///
/// Mirrors the override resolution performed during batch captioning (see
/// `StructuredCaptionRepository.buildIdeogramCaption`) but operates on an
/// already-built [IdeogramCaption]. Used when exporting the edited JSON (e.g.
/// copy-to-clipboard) so the exported value honours the configured overrides.
///
/// When [StructuredBatchOverrides.enabled] is false, [caption] is returned
/// unchanged.
IdeogramCaption applyStructuredOverrides(
  IdeogramCaption caption,
  StructuredBatchOverrides overrides,
) {
  if (!overrides.enabled) return caption;

  final IdeogramStyleDescription style = caption.styleDescription;
  final bool mediumOverridden =
      overrides.overrideMedium && overrides.medium != null;
  final String effectiveMedium = mediumOverridden
      ? overrides.medium!
      : style.medium;
  final String effectiveAesthetics =
      overrides.overrideAesthetics && overrides.aesthetics != null
      ? overrides.aesthetics!
      : style.aesthetics;
  final String effectiveLighting =
      overrides.overrideLighting && overrides.lighting != null
      ? overrides.lighting!
      : style.lighting;
  final String effectiveBackground =
      overrides.overrideBackground && overrides.background != null
      ? overrides.background!
      : caption.compositionalDeconstruction.background;

  final bool styleOverride =
      overrides.styleMode != null && overrides.styleDetail != null;
  String? photo = style.photo;
  String? artStyle = style.artStyle;
  if (styleOverride) {
    photo = overrides.styleMode == 'photo' ? overrides.styleDetail : null;
    artStyle = overrides.styleMode == 'art_style'
        ? overrides.styleDetail
        : null;
  } else if (mediumOverridden) {
    // ponytail: route existing detail into the slot matching the new medium;
    // per-medium locks if a medium toggle ever needs independent values.
    final bool isPhoto = effectiveMedium == 'photograph';
    final String detail = style.photo ?? style.artStyle ?? '';
    photo = isPhoto ? detail : null;
    artStyle = isPhoto ? null : detail;
  }

  return caption.copyWith(
    styleDescription: IdeogramStyleDescription(
      aesthetics: effectiveAesthetics,
      lighting: effectiveLighting,
      medium: effectiveMedium,
      photo: photo,
      artStyle: artStyle,
      colorPalette: style.colorPalette,
    ),
    compositionalDeconstruction: caption.compositionalDeconstruction.copyWith(
      background: effectiveBackground,
    ),
  );
}
