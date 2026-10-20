import 'dart:io' as io;
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as p;

/// Analyzer-based architecture checker (FlutterForge Phase 0).
///
/// Fails closed: compile-time resolution errors are reported as violations.
/// Sees only statically resolvable imports/declarations — dynamic coupling,
/// naming quality, sizing, and DI lifetime judgment are review guidance.
///
/// Rules:
/// - resolution-error: any compile-time error while analyzing (fail closed)
/// - presentation-imports-data: presentation may not import any data/ layer
/// - domain-purity: domain imports/exports nothing from data/, presentation/,
///   or forbidden packages (flutter UI, get_it, bloc, logging)
/// - domain-purity-reexport: domain purity through re-export (export) chains
/// - cross-feature-internal-access: feature-to-feature imports only via the
///   target feature's public barrel `features/<name>/<name>.dart`
/// - barrel-exports-internal: a barrel re-exports nothing internal
///   (`data/` internals and files outside a known layer); `domain/` models,
///   interfaces, and public `presentation/` screens/widgets are the
///   intended-public API a barrel may expose
/// - feature-dependency-cycle: feature dependency graph is acyclic
/// - core-imports-feature-internal: core/ imports features only via barrels
/// - cubit-field: no cubit/bloc stored as a field of another
///   cubit/bloc/*Service class
/// - getit-resolution-outside-allowlist: `locator<T>()`-style resolution only
///   from lib/app.dart and lib/core/di/service_locator.dart
///   (lib/core/di/service_locator.dart is still accepted until Phase 1
///   moves it)
/// - registration-outside-service-locator: `register*` calls only in
///   service_locator.dart

class ArchitectureViolation {
  const ArchitectureViolation({
    required this.path,
    required this.ruleId,
    required this.description,
  });

  /// Path relative to the checked root (e.g. `lib/features/...`).
  final String path;
  final String ruleId;
  final String description;

  @override
  String toString() => '[$ruleId] $path: $description';
}

/// Checks the package rooted at [root] (a directory containing `lib/`).
/// Generated `*.g.dart` files are exempt. Returns all violations.
Future<List<ArchitectureViolation>> checkArchitecture(String root) async {
  final String libDir = p.join(root, 'lib');
  final List<ArchitectureViolation> violations = <ArchitectureViolation>[];
  final Map<String, ResolvedUnitResult> resolved =
      <String, ResolvedUnitResult>{};

  final List<String> dartFiles = _listDartFiles(
    libDir,
  ).where((String f) => !f.endsWith('.g.dart')).toList()..sort();

  // One shared analysis context for the whole package — creating a context
  // per file (via `resolveFile`) is orders of magnitude slower.
  final AnalysisContextCollection collection = AnalysisContextCollection(
    includedPaths: <String>[libDir],
    sdkPath: _resolveSdkPath(),
  );
  final AnalysisSession session = collection.contexts.single.currentSession;

  for (final String filePath in dartFiles) {
    final SomeResolvedUnitResult someResult = await session.getResolvedUnit(
      filePath,
    );
    if (someResult is! ResolvedUnitResult) {
      violations.add(
        ArchitectureViolation(
          path: _rel(root, filePath),
          ruleId: 'resolution-error',
          description: 'fails closed: could not resolve unit',
        ),
      );
      continue;
    }
    final ResolvedUnitResult result = someResult;
    resolved[filePath] = result;

    final List<Diagnostic> compileErrors = result.diagnostics
        .where(
          (Diagnostic e) =>
              e.diagnosticCode.type == DiagnosticType.COMPILE_TIME_ERROR ||
              e.diagnosticCode.type ==
                  DiagnosticType.CHECKED_MODE_COMPILE_TIME_ERROR,
        )
        .toList();
    if (compileErrors.isNotEmpty) {
      violations.add(
        ArchitectureViolation(
          path: _rel(root, filePath),
          ruleId: 'resolution-error',
          description: 'fails closed: ${compileErrors.first.message}',
        ),
      );
      continue;
    }

    violations.addAll(_checkFile(root, filePath, result.unit));
  }

  violations.addAll(_checkDomainReexportChains(root, resolved));
  violations.addAll(_checkFeatureCycles(root, resolved));
  return violations;
}

// ---------------------------------------------------------------------------
// Per-file rules
// ---------------------------------------------------------------------------

List<ArchitectureViolation> _checkFile(
  String root,
  String filePath,
  CompilationUnit unit,
) {
  final List<ArchitectureViolation> violations = <ArchitectureViolation>[];
  final String rel = _rel(root, filePath);
  final String? feature = _featureOf(rel);
  final bool isCore = rel.startsWith('lib/core/');
  final bool isPresentation = _layerOf(rel) == 'presentation';
  final bool isDomain = _layerOf(rel) == 'domain';

  final List<_ImportEdge> importEdges = <_ImportEdge>[];
  for (final Directive directive in unit.directives) {
    if (directive is ImportDirective) {
      final _ImportEdge? edge = _resolveImport(root, filePath, directive);
      if (edge != null) {
        importEdges.add(edge);
      }
      if (isDomain && edge != null && _isForbiddenDependency(edge, root)) {
        violations.add(
          ArchitectureViolation(
            path: rel,
            ruleId: 'domain-purity',
            description:
                'domain imports forbidden dependency '
                "'${edge.uriString}'",
          ),
        );
      }
    }
    if (directive is ExportDirective) {
      final _ImportEdge? edge = _resolveExport(root, filePath, directive);
      if (edge != null) {
        if (isDomain && _isForbiddenDependency(edge, root)) {
          violations.add(
            ArchitectureViolation(
              path: rel,
              ruleId: 'domain-purity',
              description:
                  "domain exports forbidden dependency "
                  "'${edge.uriString}'",
            ),
          );
        }
        if (feature != null &&
            _isBarrel(rel, feature) &&
            _featureOf(edge.targetRel) == feature &&
            _isBarrelInternal(edge.targetRel)) {
          violations.add(
            ArchitectureViolation(
              path: rel,
              ruleId: 'barrel-exports-internal',
              description:
                  'barrel re-exports internal file '
                  "'${edge.targetRel}'",
            ),
          );
        }
      }
    }
  }

  for (final _ImportEdge edge in importEdges) {
    final String targetFeature = _featureOf(edge.targetRel) ?? '';
    final String? targetLayer = _layerOf(edge.targetRel);

    if (isPresentation && targetLayer == 'data') {
      violations.add(
        ArchitectureViolation(
          path: rel,
          ruleId: 'presentation-imports-data',
          description: "presentation imports data file '${edge.targetRel}'",
        ),
      );
    }
    if (isCore && targetFeature.isNotEmpty) {
      violations.add(
        ArchitectureViolation(
          path: rel,
          ruleId: 'core-imports-feature-internal',
          description: "core imports feature file '${edge.targetRel}'",
        ),
      );
    }
    if (feature != null &&
        targetFeature.isNotEmpty &&
        targetFeature != feature &&
        !_isBarrel(edge.targetRel, targetFeature)) {
      violations.add(
        ArchitectureViolation(
          path: rel,
          ruleId: 'cross-feature-internal-access',
          description:
              "feature '$feature' accesses '$targetFeature' internal "
              "'${edge.targetRel}' (only public barrels allowed)",
        ),
      );
    }
  }

  violations.addAll(_checkCubitFields(root, rel, unit));
  violations.addAll(_checkGetItAndRegistrations(root, rel, unit));
  return violations;
}

/// No cubit/bloc stored as a field of another cubit/bloc/*Service class,
/// determined by resolved static types (type-based, per the skill).
List<ArchitectureViolation> _checkCubitFields(
  String root,
  String rel,
  CompilationUnit unit,
) {
  final List<ArchitectureViolation> violations = <ArchitectureViolation>[];
  for (final CompilationUnitMember member in unit.declarations) {
    if (member is! ClassDeclaration) {
      continue;
    }
    final ClassElement? element = member.declaredFragment?.element;
    if (element == null) {
      continue;
    }
    final bool ownerIsBlocLike = _isBlocLike(element);
    final bool ownerIsService = element.displayName.endsWith('Service');
    if (!ownerIsBlocLike && !ownerIsService) {
      continue;
    }
    for (final FieldElement field in element.fields) {
      final Element? fieldType = field.type.element;
      if (fieldType is ClassElement && _isBlocLike(fieldType)) {
        violations.add(
          ArchitectureViolation(
            path: rel,
            ruleId: 'cubit-field',
            description:
                "'${element.displayName}' holds cubit/bloc field "
                "'${field.displayName}' (${field.type.getDisplayString()})",
          ),
        );
      }
    }
  }
  return violations;
}

bool _isBlocLike(ClassElement element) {
  if (element.displayName == 'Cubit' || element.displayName == 'Bloc') {
    return true;
  }
  for (final InterfaceType supertype in element.allSupertypes) {
    final String name = supertype.element.displayName;
    if (name == 'Cubit' || name == 'Bloc') {
      return true;
    }
  }
  return false;
}

class _GetItVisitor extends RecursiveAstVisitor<void> {
  _GetItVisitor(this.root, this.rel, this.violations);

  final String root;
  final String rel;
  final List<ArchitectureViolation> violations;

  static const Set<String> _getItFiles = <String>{
    'lib/app.dart',
    'lib/core/di/service_locator.dart',
  };

  static const Set<String> _registrationFiles = <String>{
    'lib/core/di/service_locator.dart',
  };

  /// GetIt's own registration methods. App-defined methods that merely start
  /// with "register" (e.g. `registerTabCubit`) are not DI registrations.
  static const Set<String> _getItRegistrationNames = <String>{
    'registerSingleton',
    'registerLazySingleton',
    'registerFactory',
    'registerFactoryParam',
    'registerSingletonAsync',
    'registerLazySingletonAsync',
    'registerFactoryAsync',
    'registerSingletonFactory',
  };

  void _flag(String ruleId, String description) {
    violations.add(
      ArchitectureViolation(
        path: rel,
        ruleId: ruleId,
        description: description,
      ),
    );
  }

  /// Best-effort identifier for the invoked function, e.g. `locator` in
  /// `locator<T>()` or `I` in `GetIt.I<T>()`.
  static String? _calleeName(Expression function) {
    if (function is SimpleIdentifier) {
      return function.token.lexeme;
    }
    if (function is PrefixedIdentifier) {
      return function.identifier.token.lexeme;
    }
    if (function is PropertyAccess) {
      return function.propertyName.token.lexeme;
    }
    return null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _checkInvocation(node.function);
    super.visitMethodInvocation(node);
  }

  /// After resolution, `locator<T>(...)` is a [FunctionExpressionInvocation]
  /// (function + explicit type arguments), not a [MethodInvocation] — so
  /// both invocation shapes must be checked.
  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _checkInvocation(node.function);
    super.visitFunctionExpressionInvocation(node);
  }

  void _checkInvocation(Expression function) {
    final String? calleeName = _calleeName(function);
    final bool isGetItResolution =
        (calleeName == 'locator' || calleeName == 'getIt') ||
        (function is PrefixedIdentifier &&
            <String>[
              'I',
              'instance',
            ].contains(function.identifier.token.lexeme) &&
            function.prefix.token.lexeme == 'GetIt');
    if (isGetItResolution && !_getItFiles.contains(rel)) {
      _flag(
        'getit-resolution-outside-allowlist',
        'resolves via '
            "'$function' outside the DI allowlist",
      );
    }
    if (calleeName != null &&
        _getItRegistrationNames.contains(calleeName) &&
        !_registrationFiles.contains(rel)) {
      _flag(
        'registration-outside-service-locator',
        "calls "
            "'$calleeName' outside service_locator.dart",
      );
    }
  }
}

List<ArchitectureViolation> _checkGetItAndRegistrations(
  String root,
  String rel,
  CompilationUnit unit,
) {
  final _GetItVisitor visitor = _GetItVisitor(
    root,
    rel,
    <ArchitectureViolation>[],
  );
  unit.visitChildren(visitor);
  return visitor.violations;
}

// ---------------------------------------------------------------------------
// Domain purity through re-export chains
// ---------------------------------------------------------------------------

List<ArchitectureViolation> _checkDomainReexportChains(
  String root,
  Map<String, ResolvedUnitResult> resolved,
) {
  final List<ArchitectureViolation> violations = <ArchitectureViolation>[];
  for (final MapEntry<String, ResolvedUnitResult> entry in resolved.entries) {
    final String rel = _rel(root, entry.key);
    if (_layerOf(rel) != 'domain') {
      continue;
    }
    final Set<String> visited = <String>{entry.key};
    final List<String> queue = <String>[entry.key];
    while (queue.isNotEmpty) {
      final String current = queue.removeLast();
      final CompilationUnit? unit = resolved[current]?.unit;
      if (unit == null) {
        continue;
      }
      for (final Directive directive in unit.directives) {
        if (directive is! ExportDirective) {
          continue;
        }
        final _ImportEdge? edge = _resolveExport(root, current, directive);
        if (edge == null || visited.contains(edge.targetAbs)) {
          continue;
        }
        visited.add(edge.targetAbs);
        queue.add(edge.targetAbs);
        if (_isForbiddenDependency(edge, root)) {
          violations.add(
            ArchitectureViolation(
              path: rel,
              ruleId: 'domain-purity-reexport',
              description:
                  're-export chain reaches forbidden target '
                  "'${edge.targetRel}'",
            ),
          );
        }
      }
    }
  }
  return violations;
}

// ---------------------------------------------------------------------------
// Feature dependency cycles
// ---------------------------------------------------------------------------

List<ArchitectureViolation> _checkFeatureCycles(
  String root,
  Map<String, ResolvedUnitResult> resolved,
) {
  final Map<String, Set<String>> edges = <String, Set<String>>{};
  for (final MapEntry<String, ResolvedUnitResult> entry in resolved.entries) {
    final String from = _featureOf(_rel(root, entry.key)) ?? '';
    if (from.isEmpty) {
      continue;
    }
    for (final Directive directive in entry.value.unit.directives) {
      if (directive is! ImportDirective && directive is! ExportDirective) {
        continue;
      }
      final _ImportEdge? edge = directive is ImportDirective
          ? _resolveImport(root, entry.key, directive)
          : _resolveExport(root, entry.key, directive as ExportDirective);
      if (edge == null) {
        continue;
      }
      final String to = _featureOf(edge.targetRel) ?? '';
      if (to.isEmpty || to == from) {
        continue;
      }
      edges.putIfAbsent(from, () => <String>{}).add(to);
    }
  }

  // Deterministic enumeration: sorted start nodes and neighbors, and one
  // canonical violation per sorted canonical key. Without this, which
  // representative path a DFS finds first could vary, making the ratchet's
  // stale-guard flaky.
  final List<String> startNodes = edges.keys.toList()..sort();
  final Map<String, Set<String>> sortedEdges = <String, Set<String>>{
    for (final MapEntry<String, Set<String>> e in edges.entries)
      e.key: (e.value.toList()..sort()).toSet(),
  };

  final List<ArchitectureViolation> violations = <ArchitectureViolation>[];
  final Set<String> seenCycles = <String>{};
  void dfs(String node, List<String> path, Set<String> inPath) {
    for (final String next in sortedEdges[node] ?? <String>{}) {
      if (next == path.first && path.length > 1) {
        final List<String> cycle = List<String>.of(path);
        final String key = (List<String>.of(cycle)..sort()).join('>');
        if (seenCycles.add(key)) {
          violations.add(
            ArchitectureViolation(
              path: path.join(' -> '),
              ruleId: 'feature-dependency-cycle',
              description:
                  'feature dependency cycle: '
                  '${cycle.join(' -> ')} -> ${cycle.first}',
            ),
          );
        }
      } else if (!inPath.contains(next)) {
        path.add(next);
        inPath.add(next);
        dfs(next, path, inPath);
        path.removeLast();
        inPath.remove(next);
      }
    }
  }

  for (final String node in startNodes) {
    dfs(node, <String>[node], <String>{node});
  }
  // Emit in canonical (sorted-key) order so repeated runs produce byte-
  // identical output regardless of map iteration order.
  violations.sort(
    (ArchitectureViolation a, ArchitectureViolation b) => _canonicalCycleKey(
      a.description,
    ).compareTo(_canonicalCycleKey(b.description)),
  );
  return violations;
}

/// Sort key for a cycle violation description: the canonical cycle node list.
String _canonicalCycleKey(String description) {
  final String cycle = description.contains('cycle: ')
      ? description.split('cycle: ').last
      : description;
  return cycle;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Locates a usable Dart SDK for the analyzer. Under `flutter test` the
/// analyzer's default SDK discovery fails (the tester binary lives in the
/// Flutter engine cache), so derive candidates from FLUTTER_ROOT and the
/// resolved executable.
String? _resolveSdkPath() {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final String exe = Platform.resolvedExecutable;
  final List<String> candidates = <String>[];
  if (flutterRoot != null) {
    candidates.add(p.join(flutterRoot, 'bin', 'cache', 'dart-sdk'));
  }
  // Direct dart VM: <sdk>/bin/dart.
  if (File(p.join(p.dirname(exe), 'dart')).existsSync()) {
    candidates.add(p.dirname(exe));
  }
  // Flutter tester: <flutter>/bin/cache/artifacts/engine/<arch>/<binary>.
  final RegExpMatch? flutterMatch = RegExp(
    '^(.*)/bin/cache/artifacts/engine/[^/]+/[^/]+\$',
  ).firstMatch(exe);
  if (flutterMatch != null) {
    candidates.add(p.join(flutterMatch.group(1)!, 'bin', 'cache', 'dart-sdk'));
  }
  for (final String candidate in candidates) {
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

class _ImportEdge {
  const _ImportEdge({
    required this.uriString,
    required this.targetAbs,
    required this.targetRel,
  });

  final String uriString;
  final String targetAbs;
  final String targetRel;
}

_ImportEdge? _resolveImport(
  String root,
  String filePath,
  ImportDirective directive,
) => _resolveUri(root, filePath, directive.uri.stringValue);

_ImportEdge? _resolveExport(
  String root,
  String filePath,
  ExportDirective directive,
) => _resolveUri(root, filePath, directive.uri.stringValue);

_ImportEdge? _resolveUri(String root, String filePath, String? uri) {
  if (uri == null || uri.startsWith('dart:')) {
    return null;
  }
  String abs;
  if (uri.startsWith('package:')) {
    final String rest = uri.substring('package:'.length);
    final int slash = rest.indexOf('/');
    if (slash < 0) {
      return null;
    }
    final String package = rest.substring(0, slash);
    if (package != _packageName(root)) {
      // Third-party packages are not audited exhaustively (per the skill).
      return _ImportEdge(
        uriString: uri,
        targetAbs: uri,
        targetRel: 'package:$package',
      );
    }
    abs = p.join(root, 'lib', rest.substring(slash + 1));
  } else {
    abs = p.normalize(p.join(p.dirname(filePath), uri));
  }
  return _ImportEdge(
    uriString: uri,
    targetAbs: abs,
    targetRel: _rel(root, abs),
  );
}

String? _packageName(String root) {
  final io.File pubspec = io.File(p.join(root, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    return null;
  }
  for (final String line in pubspec.readAsLinesSync()) {
    final RegExpMatch? match = RegExp(r'^name:\s*(\S+)').firstMatch(line);
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

bool _isForbiddenDependency(_ImportEdge edge, String root) {
  if (edge.uriString.startsWith('package:')) {
    return <String>[
      'package:flutter/',
      'package:get_it',
      'package:flutter_bloc',
      'package:bloc',
      'package:logging',
    ].any((String prefix) => edge.uriString.startsWith(prefix));
  }
  final String? layer = _layerOf(edge.targetRel);
  return layer == 'data' || layer == 'presentation';
}

bool _isBarrel(String rel, [String? feature]) {
  final String? f = feature ?? _featureOf(rel);
  if (f == null) {
    return false;
  }
  return rel == 'lib/features/$f/$f.dart';
}

/// True when a feature barrel must not re-export the file: `data/`
/// internals and files outside a known layer (e.g. legacy `logic/`).
/// `domain/` models/interfaces and `presentation/` screens/widgets are the
/// intended-public API.
bool _isBarrelInternal(String rel) {
  final String? layer = _layerOf(rel);
  return layer == null || layer == 'data';
}

String? _featureOf(String rel) {
  final RegExpMatch? match = RegExp('^lib/features/([^/]+)/').firstMatch(rel);
  return match?.group(1);
}

String? _layerOf(String rel) {
  final RegExpMatch? match = RegExp(
    '^lib/features/[^/]+/(data|domain|presentation)/',
  ).firstMatch(rel);
  return match?.group(1);
}

String _rel(String root, String path) {
  final String rel = p.relative(path, from: root);
  return rel.startsWith('lib/') || rel.startsWith('test/') ? rel : 'lib/$rel';
}

List<String> _listDartFiles(String dir) {
  final List<String> files = <String>[];
  if (!io.Directory(dir).existsSync()) {
    return files;
  }
  for (final io.FileSystemEntity entity in io.Directory(
    dir,
  ).listSync(recursive: true)) {
    if (entity is io.File && entity.path.endsWith('.dart')) {
      files.add(entity.path);
    }
  }
  return files;
}
