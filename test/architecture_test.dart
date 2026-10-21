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
  // Cross-feature internal access survives in exactly two places: the
  // structured-caption repository reaching CaptionService, and the
  // tab-manager cubit constructing AppFileUtils for its sessions.
  KnownViolation(
    pathPrefix:
        'lib/features/structured_captioning/data/repositories/structured_caption_repository.dart',
    ruleId: 'cross-feature-internal-access',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/tab_manager/presentation/bloc/tab_manager_cubit.dart',
    ruleId: 'cross-feature-internal-access',
  ),
  // Presentation→data survives in: the agent API panel (drives the embedded
  // REST service), the image-list cubit adapter (constructs its default
  // session's file store), structured captioning (feature-internal data),
  // and the tab-manager cubit (same session wiring).
  KnownViolation(
    pathPrefix: 'lib/features/agent_api/',
    ruleId: 'presentation-imports-data',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/image_list/presentation/bloc/image_list_cubit.dart',
    ruleId: 'presentation-imports-data',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/structured_captioning/presentation/widgets/element_detail_section.dart',
    ruleId: 'presentation-imports-data',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/structured_captioning/presentation/widgets/image_eyedropper_dialog.dart',
    ruleId: 'presentation-imports-data',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/structured_captioning/presentation/widgets/style_editor_section.dart',
    ruleId: 'presentation-imports-data',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/tab_manager/presentation/bloc/tab_manager_cubit.dart',
    ruleId: 'presentation-imports-data',
  ),
  // locator<T>() reads live only in the agent API (the DI-embedded REST
  // service and its panel), the captioning session service, the structured
  // editor page, and the tab-manager cubit/tab content widgets.
  KnownViolation(
    pathPrefix: 'lib/features/agent_api/',
    ruleId: 'getit-resolution-outside-allowlist',
  ),
  KnownViolation(
    pathPrefix:
        'lib/features/structured_captioning/presentation/pages/structured_editor_page.dart',
    ruleId: 'getit-resolution-outside-allowlist',
  ),
  KnownViolation(
    pathPrefix: 'lib/features/tab_manager/',
    ruleId: 'getit-resolution-outside-allowlist',
  ),
  // The DI layer is the one place core may import feature internals — it
  // exists precisely to wire them together.
  KnownViolation(
    pathPrefix: 'lib/core/di/service_locator.dart',
    ruleId: 'core-imports-feature-internal',
  ),
];

/// Exact canonical keys (feature names sorted, joined with ' -> ') of the
/// feature-dependency cycles accepted at Phase 0. Any NEW cycle fails the
/// suite; later phases only shrink this set.
///
/// After the controls_widgets callback inversion (image_operations no longer
/// imports tab_manager/llm_config) every cycle runs through the inherent
/// llm_config -> agent_api -> tab_manager -> main_area -> llm_config ring;
/// the first key below is the direct main_area -> llm_config shortcut.
/// Exact canonical keys (feature names sorted, joined with ' -> ') of the
/// feature-dependency cycles accepted at Phase 0. Any NEW cycle fails the
/// suite; later phases only shrink this set.
///
/// Every remaining llm_config cycle runs through the inherent
/// llm_config -> agent_api -> tab_manager -> llm_config ring; the first key
/// below is the direct llm_config -> agent_api shortcut. The only other live
/// cycle is the image_list <-> image_operations 2-cycle.
const Set<String> kKnownCycles = <String>{
  'agent_api -> llm_config',
  'agent_api -> llm_config -> structured_captioning -> tab_manager',
  'agent_api -> captioning -> llm_config -> tab_manager',
  'agent_api -> captioning -> llm_config -> structured_captioning -> tab_manager',
  'image_list -> image_operations',
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

    test('checker output is identical across repeated runs', () async {
      // Guards the ratchet against flaky stale-guard failures: cycle
      // enumeration must be deterministic (sorted start nodes/neighbors,
      // one canonical violation per canonical key, sorted emission).
      final List<ArchitectureViolation> first = await checkFixture(
        'feature_cycle',
      );
      for (int i = 0; i < 5; i++) {
        final List<ArchitectureViolation> again = await checkFixture(
          'feature_cycle',
        );
        expect(
          again.map((ArchitectureViolation v) => v.toString()).toList(),
          first.map((ArchitectureViolation v) => v.toString()).toList(),
        );
      }
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
