import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../image_list/image_list.dart';
import '../../domain/moss_training_models.dart';
import '../bloc/moss_training_export_cubit.dart';
import 'moss_training_preview.dart';

/// Dialog for the "MOSS training dataset" export mode: choose the resolution
/// budget and reconciliation policy, review the preparation plan (buckets,
/// boxes, warnings with full detail, partial clips, skips), then produce the
/// archive. Progress and cancellation are exposed; closing the dialog during
/// work cancels the run, and results stay visible after completion instead
/// of auto-closing.
///
/// Draft conversion alone does NOT prepare training geometry — this export
/// applies the trainer-identical bucket/scale/crop transform to images and
/// boxes and emits native centered captions compiled against the final
/// pixels.
class MossTrainingExportDialog extends StatefulWidget {
  const MossTrainingExportDialog({
    super.key,
    required this.images,
    required this.category,
    required this.imageListCubit,
  });

  /// Snapshot at open time — only used to build the first plan.
  final List<AppImage> images;

  /// The export category, chosen explicitly in the archive dialog; unrelated
  /// active-category changes elsewhere never alter it.
  final String category;

  /// LIVE tab session state (Codex rev-3 finding 1): staleness is checked
  /// against [ImageListCubit.state], not the frozen [images] snapshot, so a
  /// caption edited in the session invalidates the preview.
  final ImageListCubit imageListCubit;

  @override
  State<MossTrainingExportDialog> createState() =>
      _MossTrainingExportDialogState();
}

class _MossTrainingExportDialogState extends State<MossTrainingExportDialog> {
  int _resolution = 1024;
  bool _reconcileMismatchedFrames = false;

  /// Captured in [didChangeDependencies] — reading ancestors in [dispose]
  /// is unsafe once the element tree is unstable.
  MossTrainingExportCubit? _cubit;

  static const List<int> _resolutionChoices = <int>[512, 640, 768, 1024];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= context.read<MossTrainingExportCubit>();
    // A dialog freshly opened must not inherit a plan from a previous
    // session of itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cubit?.reset();
      }
    });
  }

  @override
  void dispose() {
    // Cancel in-flight work so neither the loop nor the platform save dialog
    // survives the closed dialog.
    _cubit?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MossTrainingExportCubit cubit = context
        .read<MossTrainingExportCubit>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // Interceptors: cancel first, then allow the pop on the next tick.
        cubit.cancel();
        Navigator.of(context).pop();
      },
      child: AlertDialog(
        backgroundColor: darkGrey,
        title: const Row(
          children: <Widget>[
            Icon(Icons.model_training, color: lightPink, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Export MOSS training dataset',
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
          width: 580,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: BlocConsumer<MossTrainingExportCubit, MossTrainingExportState>(
                listener: (BuildContext context, MossTrainingExportState state) {
                  if (state is MossTrainingExportError) {
                    // Errors stay visible inside the dialog body; no overlay.
                  }
                },
                builder: (BuildContext context, MossTrainingExportState state) {
                  if (state is MossTrainingExportPlanned) {
                    if (cubit.isPlanStale(
                      images: widget.images,
                      category: widget.category,
                    )) {
                      // Source set changed since audit — force a rebuild.
                      cubit.reset();
                    } else {
                      return _planView(context, state.plan);
                    }
                  }
                  if (state is MossTrainingExportError) {
                    return _optionsView(context, error: state.message);
                  }
                  if (state is MossTrainingExportDone) {
                    return _resultView(state);
                  }
                  if (state is MossTrainingExportPlanning ||
                      state is MossTrainingExporting) {
                    return _busyView(context, state);
                  }
                  return _optionsView(context);
                },
              ),
            ),
          ),
        ),
        actions: <Widget>[
          BlocBuilder<MossTrainingExportCubit, MossTrainingExportState>(
            builder: (BuildContext context, MossTrainingExportState state) {
              final bool busy =
                  state is MossTrainingExportPlanning ||
                  state is MossTrainingExporting;
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: busy
                        ? () => context.read<MossTrainingExportCubit>().cancel()
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      busy ? 'Stop' : 'Close',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _busyView(BuildContext context, MossTrainingExportState state) {
    final String label = state is MossTrainingExportPlanning
        ? 'Building plan…'
        : state is MossTrainingExporting
        ? 'Preparing ${state.processed}/${state.total}'
              '${state.currentImage == null ? '' : ' — ${state.currentImage}'}'
        : 'Working…';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        const LinearProgressIndicator(color: lightPink),
        const SizedBox(height: 10),
        const Text(
          'Stopping discards staged work — nothing is saved.',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _optionsView(BuildContext context, {String? error}) {
    final MossTrainingExportCubit cubit = context
        .read<MossTrainingExportCubit>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Prepares structured captions (Ideogram or MOSS drafts) for the '
          'pinned AI Toolkit loader: images are bucketed, uniformly scaled '
          'and centrally cropped; every caption box follows the identical '
          'transform and is re-emitted as a native centered prompt against '
          'the final pixels. The manifest records the profile and per-image '
          'transform.',
          style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            error,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.orangeAccent,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Resolution budget',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: _resolutionChoices
              .map((int r) => ButtonSegment<int>(value: r, label: Text('$r')))
              .toList(),
          selected: <int>{_resolution},
          onSelectionChanged: (Set<int> selection) =>
              setState(() => _resolution = selection.first),
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: lightPink,
          title: const Text(
            'Reconcile mismatched frames',
            style: TextStyle(fontSize: 13, color: Colors.white),
          ),
          subtitle: const Text(
            'Off (default): drafts whose declared canvas disagrees with the '
            'real image are skipped — imported layouts and changed images '
            'are never silently rescaled. On: mismatched drafts are rescaled '
            'to the real frame with the same assumption as the repair '
            'workflow.',
            style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
          ),
          value: _reconcileMismatchedFrames,
          onChanged: (bool? v) =>
              setState(() => _reconcileMismatchedFrames = v ?? false),
        ),
        const SizedBox(height: 4),
        const Text(
          'Divisibility is 16 (MOSS canvas contract). Set the trainer dataset '
          'config bucket_tolerance to 16 so the prepared dimensions are a '
          'fixed point (scale 1, crop 0 on a second pass).',
          style: TextStyle(fontSize: 11, color: Colors.white38, height: 1.3),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            text: 'Build plan',
            backgroundColor: lightPink.withAlpha(220),
            onTap: () => cubit.buildPlan(
              images: widget.images,
              category: widget.category,
              options: MossTrainingExportOptions(
                resolution: _resolution,
                allowFrameReconciliation: _reconcileMismatchedFrames,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _planView(BuildContext context, MossTrainingExportPlan plan) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${plan.items.length} pair(s) will be prepared from '
          '"${widget.category}". Review each row — warnings include partial '
          'clips and content mappings.',
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: plan.bucketSummary.entries
              .map(
                (MapEntry<String, int> e) => Chip(
                  label: Text(
                    '${e.key} ×${e.value}',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: lightGrey,
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: plan.items.length,
            itemBuilder: (BuildContext context, int index) {
              final MossTrainingPrepItem item = plan.items[index];
              final bool included = plan.entries[index].include;
              final bool hasDetail =
                  item.warnings.isNotEmpty || item.boxes.isNotEmpty;
              return ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8, left: 8),
                leading: Checkbox(
                  value: included,
                  activeColor: lightPink,
                  onChanged: (bool? v) => context
                      .read<MossTrainingExportCubit>()
                      .setInclude(index, v ?? true),
                ),
                title: Text(
                  '${item.fileName}  '
                  '${item.sourceWidth}×${item.sourceHeight} → '
                  '${item.transform.bucketWidth}×'
                  '${item.transform.bucketHeight}',
                  style: TextStyle(
                    fontSize: 12,
                    color: included ? Colors.white : Colors.white38,
                    decoration: included
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.boxes.length} box(es)'
                  '${item.droppedBoxCount > 0 ? ' · ${item.droppedBoxCount} dropped' : ''}'
                  '${item.warnings.isEmpty ? '' : ' · ${item.warnings.length} warning(s)'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: item.droppedBoxCount > 0 || item.warnings.isNotEmpty
                        ? Colors.orangeAccent
                        : Colors.white38,
                  ),
                ),
                children: <Widget>[
                  if (item.warnings.isNotEmpty)
                    Text(
                      item.warnings.map((String w) => '• $w').join('\n'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.orangeAccent,
                        height: 1.35,
                      ),
                    ),
                  // Source vs prepared crop preview with boxes (Codex rev-2
                  // finding 4): the right pane shows exactly what the
                  // central crop keeps; boxes are drawn in both frames.
                  SizedBox(
                    height: 170,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: MossCropPreviewPane(
                            imagePath: item.sourcePath,
                            imageWidth: item.sourceWidth,
                            imageHeight: item.sourceHeight,
                            viewLeft: 0,
                            viewTop: 0,
                            viewWidth: item.sourceWidth,
                            viewHeight: item.sourceHeight,
                            boxes: item.boxes
                                .map((MossTrainingBox b) => b.sourceBox)
                                .toList(),
                            label:
                                'Source (${item.sourceWidth}×'
                                '${item.sourceHeight})',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MossCropPreviewPane(
                            imagePath: item.sourcePath,
                            // Codex rev-4 finding: the prepared view window,
                            // crop offsets, and output boxes all live in the
                            // REALIZED RESIZED frame — the image drawn here
                            // must be the scaleTo frame, not the original
                            // source frame (otherwise 1864→1024 shows only
                            // the upper-left source region).
                            imageWidth: item.transform.scaleToWidth,
                            imageHeight: item.transform.scaleToHeight,
                            viewLeft: item.transform.cropX,
                            viewTop: item.transform.cropY,
                            viewWidth: item.transform.bucketWidth,
                            viewHeight: item.transform.bucketHeight,
                            boxes: item.boxes
                                .map((MossTrainingBox b) => b.outputBox)
                                .toList(),
                            label:
                                'Prepared (${item.transform.bucketWidth}×'
                                '${item.transform.bucketHeight})',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.boxes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    ...item.boxes.map(
                      (MossTrainingBox b) => Text(
                        '${b.label}: "${b.caption}" '
                        '${b.sourceBox} → ${b.outputBox ?? 'dropped'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                  if (!hasDetail)
                    const Text(
                      'No warnings, no clipping.',
                      style: TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  if (!included)
                    const Text(
                      'Excluded — will not be exported.',
                      style: TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                ],
              );
            },
          ),
        ),
        if (plan.skipped.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Skipped: ${plan.skipped.map((MossTrainingSkippedImage s) => '${s.fileName} (${s.reason})').join('; ')}',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.orangeAccent,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => context.read<MossTrainingExportCubit>().reset(),
              child: const Text(
                'Back',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              text: plan.includedCount == 0
                  ? 'Nothing to export'
                  : 'Export dataset (${plan.includedCount})',
              backgroundColor: lightPink.withAlpha(220),
              onTap: plan.includedCount == 0
                  ? null
                  : () => context.read<MossTrainingExportCubit>().exportPlan(
                      isStale: () =>
                          context.read<MossTrainingExportCubit>().isPlanStale(
                            images: widget.imageListCubit.state.images,
                            category: widget.category,
                          ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultView(MossTrainingExportDone state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          state.cancelled
              ? 'Export cancelled — no archive was saved.'
              : state.saved
              ? 'Exported ${state.result.imageCount} training pair(s).'
              : 'Prepared ${state.result.imageCount} pair(s) but the save '
                    'dialog was cancelled — no archive written.',
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
        if (state.result.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                state.result.warnings.map((String w) => '• $w').join('\n'),
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
