import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/moss_format.dart';
import '../../../../core/models/moss_repair.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/notification_overlay.dart';
import '../bloc/legacy_moss_repair/legacy_moss_repair_cubit.dart';
import '../bloc/legacy_moss_repair/legacy_moss_repair_state.dart';

/// Reviewable repair workflow for legacy MOSS drafts whose canvas was
/// 16-pixel-rounded instead of matching the real image.
///
/// Nothing is written until the user has seen the per-image audit (strategy,
/// declared vs. real canvas, item counts, old/new box overlay) and pressed
/// Apply. Each row's strategy can be overridden (reconvert / rescale / skip)
/// before applying. Results go to a new category by default so the original
/// drafts are preserved verbatim; completion shows a results view with
/// per-file diagnostics instead of auto-closing.
class LegacyMossRepairDialog extends StatefulWidget {
  const LegacyMossRepairDialog({super.key});

  @override
  State<LegacyMossRepairDialog> createState() => _LegacyMossRepairDialogState();
}

class _LegacyMossRepairDialogState extends State<LegacyMossRepairDialog> {
  late final TextEditingController _destinationController;
  bool _overwriteDestination = false;

  @override
  void initState() {
    super.initState();
    _destinationController = TextEditingController(text: 'moss-repaired');
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  String _strategyLabel(MossRepairStrategy strategy) => switch (strategy) {
    MossRepairStrategy.none => 'OK',
    MossRepairStrategy.reconvert => 'Reconvert',
    MossRepairStrategy.rescaleFrame => 'Rescale frame',
    MossRepairStrategy.skip => 'Skip',
  };

  Color _strategyColor(MossRepairStrategy strategy) => switch (strategy) {
    MossRepairStrategy.none => Colors.greenAccent,
    MossRepairStrategy.reconvert => lightPink,
    MossRepairStrategy.rescaleFrame => Colors.orangeAccent,
    MossRepairStrategy.skip => Colors.redAccent,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: darkGrey,
      title: const Row(
        children: <Widget>[
          Icon(Icons.build_circle_outlined, color: lightPink, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Repair legacy MOSS drafts',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: BlocConsumer<RepairLegacyMossCubit, LegacyMossRepairState>(
          listener: (BuildContext context, LegacyMossRepairState state) {
            if (state is LegacyMossRepairCompleted &&
                state.fatalError != null) {
              NotificationOverlay.show(context, message: state.fatalError!);
            }
          },
          builder: (BuildContext context, LegacyMossRepairState state) {
            if (state is LegacyMossRepairPreview) {
              return _preview(context, state);
            }
            if (state is LegacyMossRepairInProgress) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Repairing ${state.processed}/${state.total} — repaired '
                    '${state.repaired}, skipped ${state.skipped}'
                    '${state.failed > 0 ? ', failed ${state.failed}' : ''}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(color: lightPink),
                ],
              );
            }
            if (state is LegacyMossRepairCompleted) {
              return _completed(context, state);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Compares each stored MOSS draft against the real decoded '
                  'image dimensions. Drafts written by older conversions '
                  'declare a 16-pixel-rounded canvas that does not match the '
                  'copied image. Nothing is modified until you review the '
                  'audit and apply. Categories are bound at audit time.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _destinationController,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Destination category',
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                    filled: true,
                    fillColor: lightGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        BlocBuilder<RepairLegacyMossCubit, LegacyMossRepairState>(
          builder: (BuildContext context, LegacyMossRepairState state) {
            final bool busy = state is LegacyMossRepairInProgress;
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: busy
                      ? () => context.read<RepairLegacyMossCubit>().cancel()
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    busy ? 'Stop' : 'Close',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                if (state is! LegacyMossRepairPreview &&
                    state is! LegacyMossRepairCompleted)
                  AppButton(
                    text: 'Audit drafts',
                    backgroundColor: lightPink.withAlpha(220),
                    onTap: busy
                        ? null
                        : () => context.read<RepairLegacyMossCubit>().audit(
                            destinationCategory: _destinationController.text
                                .trim(),
                          ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, LegacyMossRepairPreview state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Audited "${state.sourceCategory}" against the live images — '
          '${state.repairable} of ${state.candidates.length} draft(s) can be '
          'repaired into "${state.destinationCategory}". Override any row '
          'below.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.candidates.length,
            itemBuilder: (BuildContext context, int index) {
              final MossRepairCandidate c = state.candidates[index];
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        c.fileName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${c.draftWidth}×${c.draftHeight} → '
                      '${c.actualWidth}×${c.actualHeight}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _strategyLabel(c.strategy),
                      style: TextStyle(
                        fontSize: 11,
                        color: _strategyColor(c.strategy),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${c.itemCount} item(s)'
                  '${c.mossEdited ? ' · edited flag set' : ''}',
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
                children: <Widget>[
                  Text(
                    c.detail,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                  if (_strategyPreview(c).isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _RepairBoxOverlayPreview(
                      imagePath: c.imagePath,
                      imageWidth: c.actualWidth,
                      imageHeight: c.actualHeight,
                      draftBoxes: _oldBoxes(c),
                      repairedBoxes: _strategyPreview(c),
                      strategyLabel: _strategyLabel(c.strategy),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final MossRepairStrategy s in <MossRepairStrategy>[
                        if (c.ideogramSourceCategory != null)
                          MossRepairStrategy.reconvert,
                        if (c.draftWidth != c.actualWidth ||
                            c.draftHeight != c.actualHeight)
                          MossRepairStrategy.rescaleFrame,
                        MossRepairStrategy.skip,
                      ])
                        TextButton(
                          onPressed:
                              c.strategy == s ||
                                  context.read<RepairLegacyMossCubit>().state
                                      is! LegacyMossRepairPreview
                              ? null
                              : () => context
                                    .read<RepairLegacyMossCubit>()
                                    .setStrategy(index, s),
                          child: Text(
                            _strategyLabel(s),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.strategy == s
                                  ? lightPink
                                  : Colors.white70,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        if (state.diagnostics.isNotEmpty)
          Text(
            state.diagnostics
                .map((MossFormatDiagnostic d) => '• $d')
                .join('\n'),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.orangeAccent,
              height: 1.3,
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: lightPink,
              title: const Text(
                'Overwrite existing destination captions',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              value: _overwriteDestination,
              onChanged: (bool? v) =>
                  setState(() => _overwriteDestination = v ?? false),
            ),
          ],
        ),
        const Text(
          'Originals are never modified: repairs are written to the '
          'destination category, tagged with the strategy used. Frame '
          'rescaling assumes the mismatch is legacy rounding — repaired boxes '
          'are quantized, not pixel-perfect recoveries.',
          style: TextStyle(fontSize: 10, color: Colors.white38, height: 1.3),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            text: 'Apply repairs',
            backgroundColor: lightPink.withAlpha(220),
            onTap: state.repairable == 0
                ? null
                : () => context.read<RepairLegacyMossCubit>().applyRepairs(
                    overwriteDestination: _overwriteDestination,
                  ),
          ),
        ),
      ],
    );
  }

  /// The box preview for the row's CURRENTLY SELECTED strategy — the
  /// overlay always shows what the chosen strategy will actually write
  /// (Codex rev-2 finding 4), not a fixed rescale preview.
  List<List<int>?> _strategyPreview(MossRepairCandidate c) =>
      c.strategy == MossRepairStrategy.reconvert
      ? c.reconvertPreview
      : c.repairedPreview;

  /// Old draft boxes for the overlay: the draft frame boxes mapped into the
  /// real frame by naive ratio (what the overlay draws as "before").
  List<List<int>?> _oldBoxes(MossRepairCandidate c) {
    // Approximate the OLD (unscaled) boxes drawn against the real frame by
    // reversing the audit's ratio, so both overlays share the same canvas.
    final double sx = c.draftWidth / c.actualWidth;
    final double sy = c.draftHeight / c.actualHeight;
    return _strategyPreview(c)
        .map(
          (List<int>? b) => b == null
              ? null
              : <int>[
                  (b[0] * sx).round(),
                  (b[1] * sy).round(),
                  (b[2] * sx).round(),
                  (b[3] * sy).round(),
                ],
        )
        .toList();
  }

  Widget _completed(BuildContext context, LegacyMossRepairCompleted state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          state.fatalError ??
              (state.cancelled
                  ? 'Cancelled — repaired ${state.repaired}, skipped '
                        '${state.skipped}, failed ${state.failed}. Written '
                        'results were kept.'
                  : 'Repaired ${state.repaired} draft(s), skipped '
                        '${state.skipped}, failed ${state.failed}.'),
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        if (state.diagnostics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                state.diagnostics
                    .map((MossFormatDiagnostic d) => '• $d')
                    .join('\n'),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orangeAccent,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Draws the draft (before) and repaired (after) boxes over the source image
/// so the reviewer can see exactly what a rescale will move. Pure Flutter —
/// no package decode; boxes are scaled to the laid-out image rect.
class _RepairBoxOverlayPreview extends StatelessWidget {
  const _RepairBoxOverlayPreview({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.draftBoxes,
    required this.repairedBoxes,
    required this.strategyLabel,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final List<List<int>?> draftBoxes;
  final List<List<int>?> repairedBoxes;
  final String strategyLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 160,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? st) =>
                          const ColoredBox(
                            color: lightGrey,
                            child: Center(
                              child: Text(
                                'image preview unavailable',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                          ),
                ),
                CustomPaint(
                  painter: _BoxOverlayPainter(
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    beforeBoxes: draftBoxes,
                    afterBoxes: repairedBoxes,
                    strategyLabel: strategyLabel,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BoxOverlayPainter extends CustomPainter {
  const _BoxOverlayPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.beforeBoxes,
    required this.afterBoxes,
    required this.strategyLabel,
  });

  final int imageWidth;
  final int imageHeight;
  final List<List<int>?> beforeBoxes;
  final List<List<int>?> afterBoxes;
  final String strategyLabel;

  @override
  void paint(Canvas canvas, Size size) {
    // BoxFit.contain letterboxing math.
    final double scale = (size.width / imageWidth < size.height / imageHeight)
        ? size.width / imageWidth
        : size.height / imageHeight;
    final double dx = (size.width - imageWidth * scale) / 2;
    final double dy = (size.height - imageHeight * scale) / 2;

    Rect toRect(List<int> b) => Rect.fromLTRB(
      dx + b[0] * scale,
      dy + b[1] * scale,
      dx + b[2] * scale,
      dy + b[3] * scale,
    );

    final Paint before = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.orangeAccent;
    final Paint after = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = lightPink;
    for (final List<int>? b in beforeBoxes) {
      if (b != null && b.length == 4) {
        canvas.drawRect(toRect(b), before);
      }
    }
    for (final List<int>? b in afterBoxes) {
      if (b != null && b.length == 4) {
        canvas.drawRect(toRect(b), after);
      }
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: strategyLabel,
        style: const TextStyle(fontSize: 9, color: lightPink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(4, 4));
  }

  @override
  bool shouldRepaint(covariant _BoxOverlayPainter oldDelegate) =>
      oldDelegate.beforeBoxes != beforeBoxes ||
      oldDelegate.afterBoxes != afterBoxes ||
      oldDelegate.strategyLabel != strategyLabel;
}
