/// Selects how the structured pipeline produces its [VlmAnalysis].
enum StructuredMode {
  /// One VLM call emits the full JSON. The original path. Best for simple
  /// images where the whole caption fits the token budget comfortably.
  singleShot,

  /// 1 enumerate call (terse per-object desc, focused on completeness) +
  /// N parallel per-element enrich calls (cropped per bbox). Best for
  /// object-heavy images that truncate or miss objects single-shot.
  multiStage,
}
