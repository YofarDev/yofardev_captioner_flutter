import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

// ─────────────────────────────────────────────────────────────────────────
// Rive-backed polish animations.
//
// Sources live in /rive at the repo root (one folder per animation, authored
// as RML and compiled with the Rive CLI). The built .riv artifacts are copied
// into assets/rive — recompile + copy after editing a scene.
//   • RiveProcessingIndicator — busy spinner for buttons / progress badges
//   • RiveDropHint            — drag-and-drop folder hint
//   • RiveEmptyStateHero      — animated hero for the no-folder empty state
// ─────────────────────────────────────────────────────────────────────────

// One loader per asset, shared by every instance and kept for the app's
// lifetime — the .riv payloads are tiny and FileLoader.file() caches the
// decoded file, so repeated mounts (e.g. every loading AppButton) reuse it.
final Map<String, FileLoader> _fileLoaders = <String, FileLoader>{};

FileLoader _sharedLoader(String asset) => _fileLoaders.putIfAbsent(
  asset,
  () => FileLoader.fromAsset(asset, riveFactory: Factory.flutter),
);

/// Autoplaying looping scene rendered into a box of the parent's choosing.
Widget _loopingScene(String asset) => RiveWidgetBuilder(
  fileLoader: _sharedLoader(asset),
  builder: (BuildContext context, RiveState state) => switch (state) {
    RiveLoaded() => RiveWidget(controller: state.controller),
    _ => const SizedBox.shrink(),
  },
);

/// Orbiting-dots spinner in neutral white tiers, so it stays legible on any
/// button or badge surface. Drops in where CircularProgressIndicator read
/// as stock.
class RiveProcessingIndicator extends StatelessWidget {
  const RiveProcessingIndicator({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _loopingScene('assets/rive/captioner_processing.riv'),
    );
  }
}

/// Open folder receiving a bobbing image chip, shown in the drop overlay
/// while files are dragged over the window. Artboard is 128x104.
class RiveDropHint extends StatelessWidget {
  const RiveDropHint({super.key, this.width = 112});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 104 / 128,
      child: _loopingScene('assets/rive/drop_hint.riv'),
    );
  }
}

/// Floating photo card whose caption lines type themselves in — the hero of
/// the empty state before any folder is opened. Artboard is 320x240.
class RiveEmptyStateHero extends StatelessWidget {
  const RiveEmptyStateHero({super.key, this.width = 300});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 240 / 320,
      child: _loopingScene('assets/rive/empty_state_hero.riv'),
    );
  }
}
