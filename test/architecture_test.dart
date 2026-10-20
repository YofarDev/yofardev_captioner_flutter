import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/architecture_checker.dart';

/// The Phase 0 ratchet: every entry suppresses a currently accepted
/// architecture violation (path prefix + rule id). Later refactoring phases
/// may only SHRINK this list — never add to it.
///
/// Cycle violations (`feature-dependency-cycle`) do not carry a lib/ path;
/// they are allowlisted separately in [kKnownCycles] by exact canonical key
/// (feature names sorted, joined with ' -> ').
const List<KnownViolation> kKnownViolations = <KnownViolation>[
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
];

/// Exact canonical keys (feature names sorted, joined with ' -> ') of the
/// feature-dependency cycles accepted at Phase 0. Any NEW cycle fails the
/// suite; later phases only shrink this set.
const Set<String> kKnownCycles = <String>{
  'agent_api -> caption_search -> captioning -> export -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> export -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> caption_search -> captioning -> export -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning',
  'agent_api -> caption_search -> captioning -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> caption_search -> captioning -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> image_operations -> llm_config -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> llm_config -> main_area -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> llm_config -> structured_captioning',
  'agent_api -> caption_search -> captioning -> image_list -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_list -> llm_config -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_operations -> llm_config -> main_area -> structured_captioning',
  'agent_api -> caption_search -> captioning -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> captioning -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> export -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> export -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning',
  'agent_api -> caption_search -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> image_list -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> caption_search -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> caption_search -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> image_list -> image_operations -> llm_config -> tab_manager',
  'agent_api -> caption_search -> image_list -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> image_list -> llm_config -> structured_captioning',
  'agent_api -> caption_search -> image_list -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> caption_search -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> export -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> export -> image_list -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> captioning -> export -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> captioning -> export -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> export -> image_list -> image_operations -> llm_config -> tab_manager',
  'agent_api -> captioning -> export -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> export -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> captioning -> export -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> main_area',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_list -> image_operations -> llm_config -> tab_manager',
  'agent_api -> captioning -> image_list -> llm_config',
  'agent_api -> captioning -> image_list -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_list -> llm_config -> main_area -> tab_manager',
  'agent_api -> captioning -> image_list -> llm_config -> structured_captioning',
  'agent_api -> captioning -> image_list -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_list -> llm_config -> tab_manager',
  'agent_api -> captioning -> image_operations -> llm_config',
  'agent_api -> captioning -> image_operations -> llm_config -> main_area -> structured_captioning',
  'agent_api -> captioning -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> captioning -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> captioning -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> image_operations -> llm_config -> tab_manager',
  'agent_api -> captioning -> llm_config',
  'agent_api -> captioning -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> llm_config -> main_area -> tab_manager',
  'agent_api -> captioning -> llm_config -> structured_captioning',
  'agent_api -> captioning -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> llm_config -> tab_manager',
  'agent_api -> export -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> export -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> export -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> export -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> export -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> image_list -> image_operations -> llm_config',
  'agent_api -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning',
  'agent_api -> image_list -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> image_list -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> image_list -> image_operations -> llm_config -> structured_captioning',
  'agent_api -> image_list -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> image_list -> image_operations -> llm_config -> tab_manager',
  'agent_api -> image_list -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> image_list -> llm_config -> structured_captioning',
  'agent_api -> image_list -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> image_operations -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> image_operations -> llm_config -> main_area -> tab_manager',
  'agent_api -> image_operations -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> image_operations -> llm_config -> tab_manager',
  'agent_api -> llm_config',
  'agent_api -> llm_config -> main_area -> structured_captioning -> tab_manager',
  'agent_api -> llm_config -> structured_captioning -> tab_manager',
  'caption_search -> captioning -> export -> image_list -> image_operations -> structured_captioning',
  'caption_search -> captioning -> image_list -> image_operations -> main_area',
  'caption_search -> captioning -> image_list -> image_operations -> main_area -> structured_captioning',
  'caption_search -> captioning -> image_list -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'caption_search -> captioning -> image_list -> image_operations -> main_area -> tab_manager',
  'caption_search -> captioning -> image_list -> image_operations -> structured_captioning',
  'caption_search -> captioning -> image_list -> image_operations -> structured_captioning -> tab_manager',
  'caption_search -> captioning -> image_list -> image_operations -> tab_manager',
  'caption_search -> captioning -> image_list -> structured_captioning',
  'caption_search -> captioning -> image_operations -> main_area -> structured_captioning',
  'caption_search -> captioning -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'caption_search -> captioning -> image_operations -> structured_captioning -> tab_manager',
  'caption_search -> export -> image_list -> image_operations -> structured_captioning',
  'caption_search -> image_list',
  'caption_search -> image_list -> image_operations -> main_area',
  'caption_search -> image_list -> image_operations -> main_area -> structured_captioning',
  'caption_search -> image_list -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'caption_search -> image_list -> image_operations -> main_area -> tab_manager',
  'caption_search -> image_list -> image_operations -> structured_captioning',
  'caption_search -> image_list -> image_operations -> structured_captioning -> tab_manager',
  'caption_search -> image_list -> image_operations -> tab_manager',
  'caption_search -> image_list -> structured_captioning',
  'caption_search -> image_operations -> main_area -> structured_captioning',
  'caption_search -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'caption_search -> image_operations -> structured_captioning -> tab_manager',
  'captioning -> export -> image_list -> image_operations',
  'captioning -> export -> image_list -> image_operations -> structured_captioning',
  'captioning -> export -> image_operations -> structured_captioning',
  'captioning -> image_list',
  'captioning -> image_list -> image_operations',
  'captioning -> image_list -> image_operations -> main_area',
  'captioning -> image_list -> image_operations -> main_area -> structured_captioning',
  'captioning -> image_list -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'captioning -> image_list -> image_operations -> main_area -> tab_manager',
  'captioning -> image_list -> image_operations -> structured_captioning',
  'captioning -> image_list -> image_operations -> structured_captioning -> tab_manager',
  'captioning -> image_list -> image_operations -> tab_manager',
  'captioning -> image_list -> structured_captioning',
  'captioning -> image_operations',
  'captioning -> image_operations -> main_area',
  'captioning -> image_operations -> main_area -> structured_captioning',
  'captioning -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'captioning -> image_operations -> main_area -> tab_manager',
  'captioning -> image_operations -> structured_captioning',
  'captioning -> image_operations -> structured_captioning -> tab_manager',
  'captioning -> image_operations -> tab_manager',
  'captioning -> structured_captioning',
  'export -> image_list -> image_operations',
  'export -> image_list -> image_operations -> structured_captioning',
  'export -> image_operations',
  'export -> image_operations -> structured_captioning',
  'image_list -> image_operations',
  'image_list -> image_operations -> main_area',
  'image_list -> image_operations -> main_area -> structured_captioning',
  'image_list -> image_operations -> main_area -> structured_captioning -> tab_manager',
  'image_list -> image_operations -> main_area -> tab_manager',
  'image_list -> image_operations -> structured_captioning',
  'image_list -> image_operations -> structured_captioning -> tab_manager',
  'image_list -> image_operations -> tab_manager',
  'image_list -> structured_captioning',
  'image_operations -> main_area',
  'image_operations -> main_area -> structured_captioning',
  'image_operations -> main_area -> structured_captioning -> tab_manager',
  'image_operations -> main_area -> tab_manager',
  'image_operations -> structured_captioning -> tab_manager',
  'image_operations -> tab_manager',
  'main_area -> tab_manager',
};

void main() {
  test('every allowlist entry still matches a live violation', () async {
    final List<ArchitectureViolation> violations = await checkArchitecture(
      Directory.current.path,
    );

    final Set<String> liveCycleKeys = violations
        .map(_cycleKey)
        .whereType<String>()
        .toSet();
    final List<ArchitectureViolation> nonCycle = violations
        .where(
          (ArchitectureViolation v) => v.ruleId != 'feature-dependency-cycle',
        )
        .toList();

    for (final KnownViolation k in kKnownViolations) {
      final bool stillLive = nonCycle.any(
        (ArchitectureViolation v) =>
            k.ruleId == v.ruleId &&
            (k.pathPrefix == '*' || v.path.startsWith(k.pathPrefix)),
      );
      expect(
        stillLive,
        isTrue,
        reason:
            'Stale allowlist entry [${k.ruleId}] ${k.pathPrefix}* — no live '
            'violation matches it anymore. Shrink kKnownViolations.',
      );
    }
    for (final String key in kKnownCycles) {
      expect(
        liveCycleKeys,
        contains(key),
        reason:
            "Stale allowlisted cycle '$key' no longer occurs. Shrink "
            'kKnownCycles.',
      );
    }
  });

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

    test('barrel-exports-internal', () async {
      final List<ArchitectureViolation> violations = await checkFixture(
        'barrel_exports_internal',
      );
      expect(_ruleIds(violations), contains('barrel-exports-internal'));
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
  if (v.ruleId == 'feature-dependency-cycle') {
    final String? key = _cycleKey(v);
    return key != null && kKnownCycles.contains(key);
  }
  return kKnownViolations.any(
    (KnownViolation k) =>
        k.ruleId == v.ruleId &&
        (k.pathPrefix == '*' || v.path.startsWith(k.pathPrefix)),
  );
}

/// Canonical key for a cycle violation: the feature names of the cycle,
/// sorted alphabetically, joined with ' -> '. Returns null for non-cycle
/// violations.
String? _cycleKey(ArchitectureViolation v) {
  if (v.ruleId != 'feature-dependency-cycle') {
    return null;
  }
  final String cycle = v.description.contains('cycle: ')
      ? v.description.split('cycle: ').last
      : v.description;
  final List<String> nodes = cycle.split(' -> ');
  if (nodes.length > 1 && nodes.last == nodes.first) {
    nodes.removeLast();
  }
  return (nodes..sort()).join(' -> ');
}

Set<String> _ruleIds(List<ArchitectureViolation> violations) =>
    violations.map((ArchitectureViolation v) => v.ruleId).toSet();
