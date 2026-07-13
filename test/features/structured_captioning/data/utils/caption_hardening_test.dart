import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/vlm_analysis.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/utils/caption_hardening.dart';

VlmStyle _style() => const VlmStyle(
  medium: 'photograph',
  aesthetics: '',
  lighting: '',
  photoOrArt: '',
);

VlmAnalysis _analysis({
  required String highLevelDescription,
  String background = '',
  List<VlmObject> objects = const <VlmObject>[],
}) => VlmAnalysis(
  highLevelDescription: highLevelDescription,
  style: _style(),
  background: background,
  objects: objects,
);

void main() {
  group('injectNoThink', () {
    test('prepends the directive once', () {
      expect(injectNoThink('describe this'), '/no_think\n\ndescribe this');
    });

    test('is idempotent when already present', () {
      const String prefixed = '/no_think\n\ndescribe this';
      expect(injectNoThink(prefixed), prefixed);
    });
  });

  group('stripThinking', () {
    test('removes a think block and trims', () {
      const String raw =
          '<think>let me reason</think>{"high_level_description":"x"}';
      expect(stripThinking(raw), '{"high_level_description":"x"}');
    });

    test('handles multi-line blocks', () {
      const String raw = '<think>\nline one\nline two\n</think>answer';
      expect(stripThinking(raw), 'answer');
    });

    test('leaves content without think tags unchanged (trimmed)', () {
      expect(stripThinking('  plain  '), 'plain');
    });
  });

  group('captionHealthIssues', () {
    test('flags empty output as fatal', () {
      final List<String> issues = captionHealthIssues(
        _analysis(highLevelDescription: ''),
      );
      expect(issues, isNotEmpty);
      expect(hasFatalHealthIssue(issues), isTrue);
    });

    test('flags a refusal as fatal', () {
      final List<String> issues = captionHealthIssues(
        _analysis(
          highLevelDescription: "I'm sorry, I can't help with that.",
          objects: <VlmObject>[const VlmObject(name: 'x', desc: 'y')],
        ),
      );
      expect(issues.any((String s) => s.startsWith('refusal')), isTrue);
      expect(hasFatalHealthIssue(issues), isTrue);
    });

    test('flags degenerate repetition as a soft issue', () {
      final List<String> issues = captionHealthIssues(
        _analysis(
          highLevelDescription: 'a desk a desk a desk a desk a desk a desk',
          objects: <VlmObject>[
            const VlmObject(name: 'desk', desc: 'wooden desk'),
          ],
        ),
      );
      expect(issues.any((String s) => s.startsWith('repetitive')), isTrue);
      expect(hasFatalHealthIssue(issues), isFalse);
    });

    test('returns no issues for healthy output', () {
      final List<String> issues = captionHealthIssues(
        _analysis(
          highLevelDescription: 'A wooden desk in a white room.',
          objects: <VlmObject>[
            const VlmObject(name: 'desk', desc: 'a brown wooden desk'),
          ],
        ),
      );
      expect(issues, isEmpty);
    });

    test('flags dominant object-kind collapse as a soft issue', () {
      final List<String> issues = captionHealthIssues(
        _analysis(
          highLevelDescription: 'A furnished apartment interior.',
          objects: const <VlmObject>[
            VlmObject(name: 'potted plants', desc: 'upper left plants'),
            VlmObject(name: 'plant', desc: 'lower plant'),
            VlmObject(name: 'green plants', desc: 'right plants'),
            VlmObject(name: 'hanging plant', desc: 'wall plant'),
            VlmObject(name: 'small plant', desc: 'table plant'),
            VlmObject(name: 'sofa', desc: 'orange sofa'),
          ],
        ),
      );

      expect(
        issues.any((String s) => s.contains('collapsed onto one category')),
        isTrue,
      );
      expect(hasFatalHealthIssue(issues), isFalse);
    });
  });
}
