// Advisory debug tool; prints the violation report.
// ignore_for_file: avoid_print

import '../test/support/architecture_checker.dart';

Future<void> main() async {
  final List<ArchitectureViolation> violations = await checkArchitecture(
    '/Users/yofardev/development/Projects/Flutter/yofardev_captioner',
  );
  for (final ArchitectureViolation v in violations) {
    print('${v.ruleId}\t${v.path}\t${v.description}');
  }
  print('TOTAL: ${violations.length}');
}
