// Advisory debug tool; prints the violation report.
// ignore_for_file: avoid_print

import 'dart:io';

import '../test/support/architecture_checker.dart';

Future<void> main() async {
  final List<ArchitectureViolation> violations = await checkArchitecture(
    Directory.current.path,
  );
  for (final ArchitectureViolation v in violations) {
    print('${v.ruleId}\t${v.path}\t${v.description}');
  }
  print('TOTAL: ${violations.length}');
}
