/// Quality report for a multi-stage run, describing which elements were
/// enriched, skipped, pruned, or had their enrich responses rejected.
class MultiStageQualityReport {
  const MultiStageQualityReport({
    this.fullCanvasBboxes = const <int>[],
    this.nearFullCanvasBboxes = const <int>[],
    this.duplicateCandidates = const <int>[],
    this.skippedEnrichments = const <int>[],
    this.enrichFailures = const <int>[],
    this.enrichRejections = const <int>[],
  });

  final List<int> fullCanvasBboxes;
  final List<int> nearFullCanvasBboxes;
  final List<int> duplicateCandidates;
  final List<int> skippedEnrichments;
  final List<int> enrichFailures;
  final List<int> enrichRejections;

  bool get hasIssues =>
      fullCanvasBboxes.isNotEmpty ||
      nearFullCanvasBboxes.isNotEmpty ||
      duplicateCandidates.isNotEmpty ||
      enrichFailures.isNotEmpty ||
      enrichRejections.isNotEmpty;

  String toFormattedString() {
    final StringBuffer buf = StringBuffer();
    buf.writeln('quality_report');
    buf.writeln('=============');
    if (fullCanvasBboxes.isNotEmpty) {
      buf.writeln('full-canvas bboxes: [${fullCanvasBboxes.join(', ')}]');
    }
    if (nearFullCanvasBboxes.isNotEmpty) {
      buf.writeln(
        'near-full-canvas bboxes (>80%): [${nearFullCanvasBboxes.join(', ')}]',
      );
    }
    if (duplicateCandidates.isNotEmpty) {
      buf.writeln(
        'duplicate candidates (pruned): [${duplicateCandidates.join(', ')}]',
      );
    }
    if (skippedEnrichments.isNotEmpty) {
      buf.writeln('skipped enrichments: [${skippedEnrichments.join(', ')}]');
    }
    if (enrichFailures.isNotEmpty) {
      buf.writeln('enrich parse failures: [${enrichFailures.join(', ')}]');
    }
    if (enrichRejections.isNotEmpty) {
      buf.writeln(
        'enrich sanity-check rejections: [${enrichRejections.join(', ')}]',
      );
    }
    return buf.toString();
  }
}
