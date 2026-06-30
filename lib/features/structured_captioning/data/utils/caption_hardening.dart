import '../models/vlm_analysis.dart';

/// Prepends the `/no_think` directive understood by Qwen3-family reasoning
/// models so they spend their token budget on the answer instead of an
/// internal `<think>` block. Harmless for models that don't recognize it —
/// they either ignore it or emit it verbatim into the prompt without effect.
///
/// Idempotent: returns the input unchanged when it already starts with the
/// directive.
String injectNoThink(String userPrompt) {
  if (userPrompt.trimLeft().startsWith('/no_think')) {
    return userPrompt;
  }
  return '/no_think\n\n$userPrompt';
}

/// Removes `<think>...</think>` blocks a reasoning model may emit before its
/// final answer. Non-greedy + dot-all so it handles multi-line blocks.
String stripThinking(String content) {
  return content
      .replaceAll(
        RegExp('<think>.*?</think>', dotAll: true, caseSensitive: false),
        '',
      )
      .trim();
}

// Phrases that signal the model refused or chatted instead of producing a
// caption. Lowercased — compared against a lowercased text blob.
const List<String> _kRefusalMarkers = <String>[
  "i'm sorry",
  'i am sorry',
  'i cannot',
  "i can't",
  'i can not',
  'as an ai',
  "i'm unable",
  'i am unable',
  'unable to assist',
  'cannot assist',
  "can't help",
  "i won't be able",
  'i will not',
  "i'm not able",
  'against my',
  'as a language model',
];

/// True when [text] contains the same word (or short phrase) repeated
/// back-to-back `minRun`+ times — a cheap degenerate-output detector.
bool _hasRunawayRepetition(String text, {int minRun = 6}) {
  final List<String> words = text.split(RegExp(r'\s+'));
  if (words.length < minRun * 2) return false;

  int run = 1;
  for (int i = 1; i < words.length; i++) {
    run = words[i] == words[i - 1] ? run + 1 : 1;
    if (run >= minRun) return true;
  }

  for (final int size in const <int>[2, 3, 4]) {
    if (words.length < size * minRun) continue;
    run = 1;
    for (int i = size; i <= words.length - size; i += size) {
      final bool same = _sliceEquals(words, i - size, i, size);
      run = same ? run + 1 : 1;
      if (run >= minRun) return true;
    }
  }
  return false;
}

bool _sliceEquals(List<String> words, int aStart, int bStart, int size) {
  for (int k = 0; k < size; k++) {
    if (words[aStart + k] != words[bStart + k]) return false;
  }
  return true;
}

/// Cheap structural health checks on a parsed VLM analysis.
///
/// Returns a list of human-readable issue strings; an empty list means the
/// output looks structurally fine. Catches refusals, degenerate repetition,
/// and empty outputs — NOT semantic hallucinations (those need the image).
///
/// Issue strings starting with `empty` or `refusal` are treated as fatal by
/// the caller (the image is marked failed and retryable); other issues are
/// soft warnings.
List<String> captionHealthIssues(VlmAnalysis analysis) {
  final List<String> texts = <String>[
    analysis.highLevelDescription,
    analysis.background,
    analysis.style.aesthetics,
    analysis.style.lighting,
    analysis.style.photoOrArt,
    for (final VlmObject o in analysis.objects) ...<String>[
      o.name,
      o.desc,
      o.text ?? '',
    ],
  ];
  final List<String> nonEmpty =
      texts.where((String s) => s.trim().isNotEmpty).toList();

  if (analysis.highLevelDescription.trim().isEmpty &&
      analysis.objects.isEmpty) {
    return const <String>['empty output — no description and no objects'];
  }

  final List<String> issues = <String>[];
  final String blob = nonEmpty.join(' ').toLowerCase();
  if (_kRefusalMarkers.any((String m) => blob.contains(m))) {
    issues.add('refusal: looks like the model declined instead of captioning');
  }
  if (nonEmpty.any((String s) => _hasRunawayRepetition(s))) {
    issues.add('repetitive / degenerate text');
  }
  return issues;
}

/// True when any issue is fatal (the run should abort for this image).
bool hasFatalHealthIssue(List<String> issues) {
  return issues.any(
    (String s) => s.startsWith('empty') || s.startsWith('refusal'),
  );
}
