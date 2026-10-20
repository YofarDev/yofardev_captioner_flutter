import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/architecture_checker.dart';

/// The Phase 0 ratchet: every entry suppresses a currently accepted
/// architecture violation (path prefix + rule id). Later refactoring phases
/// may only SHRINK this list — never add to it.
const List<KnownViolation> kKnownViolations = <KnownViolation>[
  // Feature dependency graph is heavily cyclic; enumerated cycles explode
  // combinatorially, so the rule is allowlisted wholesale until Phase 1+.
  KnownViolation(pathPrefix: '*', ruleId: 'feature-dependency-cycle'),
  // No feature barrels exist yet; every cross-feature import targets an
  // internal file.
  KnownViolation(
    pathPrefix: 'lib/features/',
    ruleId: 'cross-feature-internal-access',
  ),
  KnownViolation(
    pathPrefix: 'lib/features/',
    ruleId: 'presentation-imports-data',
  ),
  KnownViolation(pathPrefix: 'lib/features/', ruleId: 'cubit-field'),
  KnownViolation(
    pathPrefix: 'lib/features/',
    ruleId: 'getit-resolution-outside-allowlist',
  ),
  KnownViolation(
    pathPrefix: 'lib/core/',
    ruleId: 'core-imports-feature-internal',
  ),
  KnownViolation(
    pathPrefix: 'lib/core/',
    ruleId: 'cross-feature-internal-access',
  ),
  // main.dart registers the root cubits and starts the Agent API during
  // bootstrap; both move to the service locator in Phase 1.
  KnownViolation(
    pathPrefix: 'lib/main.dart',
    ruleId: 'registration-outside-service-locator',
  ),
  KnownViolation(
    pathPrefix: 'lib/main.dart',
    ruleId: 'getit-resolution-outside-allowlist',
  ),
];

void main() {
  test('real lib/ passes architecture rules except known violations', () async {
    final String root = Directory.current.path;
    final List<ArchitectureViolation> violations = await checkArchitecture(
      root,
    );

    final List<ArchitectureViolation> unexpected = violations
        .where((ArchitectureViolation v) => !_isKnown(v))
        .toList();

    expect(
      unexpected,
      isEmpty,
      reason:
          'New architecture violations introduced. Fix them or (only '
          'during an approved refactor phase) shrink kKnownViolations. '
          'Found: ${unexpected.take(20).join('; ')}',
    );
  });

  group('negative fixtures (each must fail its rule)', () {
    String fixtureRoot(String name) => p.join(
      Directory.current.path,
      'test',
      'support',
      'architecture_fixtures',
      name,
    );

    Future<List<ArchitectureViolation>> checkFixture(String name) =>
        checkArchitecture(fixtureRoot(name));

    test('presentation-imports-data', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'presentation_imports_data',
      );
      expect(_ruleIds(violations), contains('presentation-imports-data'));
    });

    test('domain-purity (import)', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'domain_purity',
      );
      expect(_ruleIds(violations), contains('domain-purity'));
    });

    test('domain-purity-reexport', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'domain_purity',
      );
      expect(_ruleIds(violations), contains('domain-purity-reexport'));
    });

    test('cross-feature-internal-access', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'cross_feature',
      );
      expect(_ruleIds(violations), contains('cross-feature-internal-access'));
    });

    test('cross-feature via public barrel is allowed', () async {
      // Only the internal-access import above may fire; the same fixture
      // package contains a barrel that must NOT be flagged as a target.
      final List<ArchitectureViolation> violations = await checkFixture(
        'cross_feature',
      );
      final List<ArchitectureViolation> barrelHits = violations
          .where(
            (ArchitectureViolation v) =>
                v.ruleId == 'cross-feature-internal-access' &&
                v.description.contains("'lib/features/b/b.dart'"),
          )
          .toList();
      expect(barrelHits, isEmpty);
    });

    test('feature-dependency-cycle', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'feature_cycle',
      );
      expect(_ruleIds(violations), contains('feature-dependency-cycle'));
    });

    test('core-imports-feature-internal', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'core_imports_internal',
      );
      expect(_ruleIds(violations), contains('core-imports-feature-internal'));
    });

    test('cubit-field', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'cubit_field',
      );
      expect(_ruleIds(violations), contains('cubit-field'));
    });

    test('getit-resolution-outside-allowlist', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'getit_outside',
      );
      expect(
        _ruleIds(violations),
        contains('getit-resolution-outside-allowlist'),
      );
    });

    test('registration-outside-service-locator', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'getit_outside',
      );
      expect(
        _ruleIds(violations),
        contains('registration-outside-service-locator'),
      );
    });

    test('fails closed on resolution errors', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'resolution_error',
      );
      expect(_ruleIds(violations), contains('resolution-error'));
    });
  });
}

class KnownViolation {
  const KnownViolation({required this.pathPrefix, required this.ruleId});

  final String pathPrefix;
  final String ruleId;

  @override
  String toString() => '[$ruleId] $pathPrefix*';
}

bool _isKnown(ArchitectureViolation v) {
  return kKnownViolations.any(
    (KnownViolation k) =>
        k.ruleId == v.ruleId &&
        (k.pathPrefix == '*' || v.path.startsWith(k.pathPrefix)),
  );
}

Set<String> _ruleIds(List<ArchitectureViolation> violations) =>
    violations.map((ArchitectureViolation v) => v.ruleId).toSet();
