import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/moss_format.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../../core/widgets/app_button.dart';
import '../bloc/format_conversion/convert_format_cubit.dart';
import '../bloc/format_conversion/convert_format_state.dart';

/// Dialog that batch-converts structured captions in the active category
/// between the Ideogram and MOSS JSON formats (local conversion, no LLM).
///
/// Subscribes to the cubit so progress, partial totals, and diagnostics are
/// visible; the Convert action is disabled while a run is in flight and the
/// Stop action cancels future work (already-written captions are kept).
class ConvertFormatDialog extends StatefulWidget {
  const ConvertFormatDialog({super.key});

  @override
  State<ConvertFormatDialog> createState() => _ConvertFormatDialogState();
}

class _ConvertFormatDialogState extends State<ConvertFormatDialog> {
  CaptionFormat _target = CaptionFormat.moss;
  bool _inPlace = false;
  bool _overwriteExisting = false;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(text: 'moss');
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Widget _resultsView(ConvertFormatCompleted state) {
    final String summary;
    if (state.fatalError != null) {
      summary = state.fatalError!;
    } else if (state.cancelled) {
      summary =
          'Cancelled — converted ${state.converted}, skipped '
          '${state.skipped}, failed ${state.failed}. Written results were '
          'kept.';
    } else if (state.converted == 0 &&
        state.skipped == 0 &&
        state.failed == 0) {
      summary = 'Nothing to convert';
    } else {
      summary =
          'Converted ${state.converted}, skipped ${state.skipped}, '
          'failed ${state.failed}';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(summary, style: const TextStyle(fontSize: 13, color: textPrimary)),
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
                  color: amberWarn,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _start(BuildContext context) async {
    final ConvertFormatCubit cubit = context.read<ConvertFormatCubit>();
    await cubit.apply(
      target: _target,
      inPlace: _inPlace,
      newCategoryName: _inPlace ? null : _categoryController.text,
      overwriteExisting: _overwriteExisting,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: darkGrey,
      title: const Row(
        children: <Widget>[
          Icon(Icons.transform, color: lightPink, size: 22),
          SizedBox(width: 10),
          Text(
            'Convert caption format',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: BlocConsumer<ConvertFormatCubit, ConvertFormatState>(
          listener: (BuildContext context, ConvertFormatState state) {},
          builder: (BuildContext context, ConvertFormatState state) {
            final bool running = state is ConvertFormatInProgress;
            if (state is ConvertFormatCompleted) {
              return _resultsView(state);
            }
            final String progressLabel = running
                ? '${state.processedImages}/${state.totalImages}'
                      '${state.currentImageName == null ? '' : ' — ${state.currentImageName}'}'
                : '';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Locally converts structured captions in the active category '
                  'between the Ideogram and MOSS JSON formats. No LLM is used. '
                  'MOSS boxes are projected onto the exact source image '
                  'dimensions.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Target format',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                SegmentedButton<CaptionFormat>(
                  segments: const <ButtonSegment<CaptionFormat>>[
                    ButtonSegment<CaptionFormat>(
                      value: CaptionFormat.moss,
                      label: Text('MOSS'),
                    ),
                    ButtonSegment<CaptionFormat>(
                      value: CaptionFormat.ideogram,
                      label: Text('Ideogram'),
                    ),
                  ],
                  selected: <CaptionFormat>{_target},
                  onSelectionChanged: running
                      ? null
                      : (Set<CaptionFormat> selection) {
                          setState(() {
                            _target = selection.first;
                            if (!_inPlace) {
                              _categoryController.text =
                                  _target == CaptionFormat.moss
                                  ? 'moss'
                                  : 'ideogram';
                            }
                          });
                        },
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    side: const WidgetStatePropertyAll<BorderSide>(
                      BorderSide(color: hairline),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (Set<WidgetState> states) =>
                          states.contains(WidgetState.selected)
                          ? lightPink.withValues(alpha: 0.25)
                          : null,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (Set<WidgetState> states) =>
                          states.contains(WidgetState.selected)
                          ? lightPink
                          : textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: lightPink,
                  title: const Text(
                    'Overwrite in place',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Unchecked: write into a new category instead',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  value: _inPlace,
                  onChanged: running
                      ? null
                      : (bool? v) => setState(() => _inPlace = v ?? false),
                ),
                if (!_inPlace) ...<Widget>[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _categoryController,
                    enabled: !running,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Target category',
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
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: lightPink,
                    title: const Text(
                      'Overwrite existing destination captions',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Unchecked: images that already have a caption in the '
                      'target category are skipped',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    value: _overwriteExisting,
                    onChanged: running
                        ? null
                        : (bool? v) =>
                              setState(() => _overwriteExisting = v ?? false),
                  ),
                ],
                if (running) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: lightPink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          progressLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'converted ${state.converted} · skipped ${state.skipped} '
                    '· failed ${state.failed}',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if (state.diagnostics.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
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
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        BlocBuilder<ConvertFormatCubit, ConvertFormatState>(
          builder: (BuildContext context, ConvertFormatState state) {
            final bool running = state is ConvertFormatInProgress;
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: running
                      ? () => context.read<ConvertFormatCubit>().cancel()
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    running ? 'Stop' : 'Cancel',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  text: 'Convert',
                  backgroundColor: lightPink.withAlpha(220),
                  onTap: running ? null : () => _start(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
