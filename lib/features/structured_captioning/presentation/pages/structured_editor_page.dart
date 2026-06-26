import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../llm_config/data/models/structured_batch_overrides.dart';
import '../../../llm_config/logic/llm_configs_cubit.dart';
import '../../data/models/apply_structured_overrides.dart';
import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import '../widgets/element_detail_section.dart';
import '../widgets/ideogram_caption_view.dart';
import '../widgets/interactive_bbox_canvas.dart';
import '../widgets/layers_panel.dart';
import '../widgets/style_editor_section.dart';

class StructuredEditorPage extends StatelessWidget {
  const StructuredEditorPage({
    required this.imageFile,
    required this.captionJson,
    required this.activeCategory,
    required this.imageListCubit,
    super.key,
  });

  final File imageFile;
  final String captionJson;
  final String activeCategory;
  final ImageListCubit imageListCubit;

  @override
  Widget build(BuildContext context) {
    return _StructuredEditorScope(
      initialImageFile: imageFile,
      initialCaptionJson: captionJson,
      activeCategory: activeCategory,
      imageListCubit: imageListCubit,
    );
  }
}

/// Owns the currently viewed image so the editor can swap images in place.
///
/// Switching image rebuilds the [BlocProvider] with a fresh key, disposing the
/// previous cubit (which flushes any pending save) and creating a new one for
/// the next image.
class _StructuredEditorScope extends StatefulWidget {
  const _StructuredEditorScope({
    required this.initialImageFile,
    required this.initialCaptionJson,
    required this.activeCategory,
    required this.imageListCubit,
  });

  final File initialImageFile;
  final String initialCaptionJson;
  final String activeCategory;
  final ImageListCubit imageListCubit;

  @override
  State<_StructuredEditorScope> createState() => _StructuredEditorScopeState();
}

class _StructuredEditorScopeState extends State<_StructuredEditorScope> {
  late File _imageFile;
  late String _captionJson;
  late String _imageId;
  StructuredEditorCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialImageFile;
    _captionJson = widget.initialCaptionJson;
    _imageId = widget.imageListCubit.currentDisplayedImage?.id ?? '';
  }

  /// Moves to the nearest image (in [forward] direction) whose active-category
  /// caption is valid Ideogram4 JSON.
  ///
  /// Flushes the current cubit's pending save *before* changing the image list
  /// pointer, because [ImageListCubit.updateCaption] writes to whichever image
  /// is current — flipping the pointer first would persist edits on the wrong
  /// image. Images without a parseable structured caption are skipped, since
  /// the editor cannot render them.
  Future<void> _navigate({required bool forward}) async {
    final StructuredEditorCubit? cubit = _cubit;
    if (cubit != null) {
      await cubit.flushSave();
    }

    final ImageListCubit list = widget.imageListCubit;
    final List<AppImage> displayed = list.displayedImages;
    if (displayed.length < 2) return;

    final int currentIndex = displayed.indexWhere(
      (AppImage i) => i.id == _imageId,
    );
    if (currentIndex == -1) return;

    AppImage? target;
    for (int step = 1; step <= displayed.length; step++) {
      final int candidateIndex = forward
          ? (currentIndex + step) % displayed.length
          : (currentIndex - step + displayed.length) % displayed.length;
      final AppImage candidate = displayed[candidateIndex];
      final String caption =
          candidate.captions[widget.activeCategory]?.text ?? '';
      if (IdeogramCaptionView.isIdeogramJson(caption)) {
        target = candidate;
        break;
      }
    }

    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other image with a structured caption'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    list.onImageSelected(target.id);

    setState(() {
      _imageFile = target!.image;
      _captionJson = target.captions[widget.activeCategory]?.text ?? '';
      _imageId = target.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StructuredEditorCubit>(
      key: ValueKey<String>(_imageId),
      create: (BuildContext context) {
        // Capture the instance so [_navigate] can flush it without needing a
        // descendant [BuildContext] (the provider sits in this widget's child,
        // so the scope's own context cannot read it).
        final StructuredEditorCubit cubit = StructuredEditorCubit(
          initialCaption: IdeogramCaption.fromJson(
            jsonDecode(_captionJson) as Map<String, dynamic>,
          ),
          imageFile: _imageFile,
          activeCategory: widget.activeCategory,
          imageListCubit: widget.imageListCubit,
        );
        _cubit = cubit;
        return cubit;
      },
      child: _StructuredEditorView(
        imageListCubit: widget.imageListCubit,
        onPrevious: () => _navigate(forward: false),
        onNext: () => _navigate(forward: true),
      ),
    );
  }
}

class _StructuredEditorView extends StatelessWidget {
  const _StructuredEditorView({
    required this.imageListCubit,
    required this.onPrevious,
    required this.onNext,
  });

  final ImageListCubit imageListCubit;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final String filename = context
        .read<StructuredEditorCubit>()
        .state
        .imageFile
        .path
        .split('/')
        .last;

    return Scaffold(
      backgroundColor: darkGrey,
      appBar: AppBar(
        backgroundColor: lightGrey,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          filename,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          // SAM3 bbox comparison toggle.
          BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
            buildWhen:
                (StructuredEditorState prev, StructuredEditorState next) =>
                    prev.showSamBboxes != next.showSamBboxes ||
                    prev.samComputeStatus != next.samComputeStatus,
            builder: (BuildContext context, StructuredEditorState state) {
              final bool computing =
                  state.samComputeStatus == SamComputeStatus.computing;
              final bool on = state.showSamBboxes;
              final bool errored =
                  state.samComputeStatus == SamComputeStatus.error;

              final IconData icon = on
                  ? Icons.center_focus_strong
                  : Icons.center_focus_strong_outlined;
              final Color color = on
                  ? Colors.tealAccent
                  : (errored ? Colors.redAccent : Colors.white);

              return IconButton(
                icon: computing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, color: color),
                tooltip: computing
                    ? 'Running SAM3…'
                    : (on
                          ? 'Show saved (VLM) bboxes'
                          : (errored
                                ? 'SAM3 failed — click to retry'
                                : 'Show SAM3 bboxes')),
                onPressed: computing
                    ? null
                    : () {
                        context.read<StructuredEditorCubit>().toggleSamBboxes();
                      },
              );
            },
          ),
          _NavArrow(
            icon: Icons.chevron_left,
            tooltip: 'Previous image (←)',
            onTap: onPrevious,
          ),
          BlocBuilder<ImageListCubit, ImageListState>(
            bloc: imageListCubit,
            builder: (BuildContext context, ImageListState state) {
              final List<AppImage> displayed = imageListCubit.displayedImages;
              final int idx = imageListCubit.currentDisplayedImage == null
                  ? 0
                  : displayed.indexWhere(
                      (AppImage i) =>
                          i.id == imageListCubit.currentDisplayedImage!.id,
                    );
              final int position = idx < 0 ? 0 : idx + 1;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$position / ${displayed.length}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
          _NavArrow(
            icon: Icons.chevron_right,
            tooltip: 'Next image (→)',
            onTap: onNext,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onPrevious,
          const SingleActivator(LogicalKeyboardKey.arrowRight): onNext,
          // ponytail: no confirm/undo — matches the layer-tile delete button;
          // add undo stack if accidental deletes become a problem.
          const SingleActivator(LogicalKeyboardKey.delete):
              () => _removeSelectedElement(context),
          const SingleActivator(LogicalKeyboardKey.backspace):
              () => _removeSelectedElement(context),
        },
        child: const Focus(
          autofocus: true,
          child: Row(
            children: <Widget>[
              // Left panel: image + layers
              Expanded(
                flex: 3,
                child: Column(
                  children: <Widget>[
                    Expanded(flex: 3, child: InteractiveBboxCanvas()),
                    SizedBox(height: 4),
                    Expanded(flex: 2, child: LayersPanel()),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: Colors.white24),
              // Right panel: field editors
              Expanded(flex: 2, child: _RightPanel()),
            ],
          ),
        ),
      ),
    );
  }

  /// Removes the currently selected layer/element. Keyboard shortcut target.
  void _removeSelectedElement(BuildContext context) {
    final StructuredEditorCubit cubit = context.read<StructuredEditorCubit>();
    final int? selected = cubit.state.selectedElementIndex;
    if (selected == null) return;
    cubit.removeElement(selected);
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: () => onTap(),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // High-level description
              const _SectionLabel('Description'),
              const SizedBox(height: 6),
              _EditableField(
                value: state.caption.highLevelDescription,
                maxLines: 4,
                onChanged: (String v) => context
                    .read<StructuredEditorCubit>()
                    .updateHighLevelDescription(v),
              ),
              const SizedBox(height: 20),

              // Style section
              const StyleEditorSection(),
              const SizedBox(height: 20),

              // Background
              const _SectionLabel('Background'),
              const SizedBox(height: 6),
              _EditableField(
                value: state.caption.compositionalDeconstruction.background,
                maxLines: 4,
                onChanged: (String v) =>
                    context.read<StructuredEditorCubit>().updateBackground(v),
              ),
              const SizedBox(height: 20),

              // Selected element detail
              if (state.isElementSelected) const ElementDetailSection(),
              const SizedBox(height: 20),
              const _JsonViewer(),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }
}

class _EditableField extends StatefulWidget {
  const _EditableField({
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String value;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      final int selEnd = _controller.selection.baseOffset;
      _controller.text = widget.value;
      final int newCursorPos = selEnd.clamp(0, widget.value.length);
      _controller.selection = TextSelection.collapsed(offset: newCursorPos);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: widget.maxLines,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _JsonViewer extends StatefulWidget {
  const _JsonViewer();

  @override
  State<_JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<_JsonViewer> {
  bool _expanded = false;
  bool _editing = false;
  String? _parseError;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enterEdit(String currentRaw) {
    _controller.text = currentRaw;
    setState(() {
      _expanded = true;
      _editing = true;
      _parseError = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _parseError = null;
    });
  }

  void _apply(BuildContext context) {
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(_controller.text) as Map<String, dynamic>;
      final IdeogramCaption caption = IdeogramCaption.fromJson(decoded);
      context.read<StructuredEditorCubit>().replaceCaption(caption);
      setState(() {
        _editing = false;
        _parseError = null;
      });
    } catch (e) {
      setState(() => _parseError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final StructuredBatchOverrides overrides = context
        .select<LlmConfigsCubit, StructuredBatchOverrides>(
          (LlmConfigsCubit c) => c.state.llmConfigs.structuredBatchOverrides,
        );
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final String raw = const JsonEncoder.withIndent(
          '  ',
        ).convert(state.caption.toJson());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _expanded ? Icons.expand_less : Icons.code,
                      size: 18,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Raw JSON',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    if (overrides.enabled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'overrides',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (_expanded && !_editing) ...<Widget>[
                      InkWell(
                        onTap: () => _enterEdit(raw),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    InkWell(
                      onTap: () {
                        final IdeogramCaption copyCaption =
                            applyStructuredOverrides(state.caption, overrides);
                        final String copyText = const JsonEncoder.withIndent(
                          '  ',
                        ).convert(copyCaption.toJson());
                        Clipboard.setData(ClipboardData(text: copyText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              overrides.enabled
                                  ? 'JSON copied to clipboard (overrides applied)'
                                  : 'JSON copied to clipboard',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...<Widget>[
              const SizedBox(height: 8),
              if (_editing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightGrey,
                    borderRadius: BorderRadius.circular(8),
                    border: _parseError != null
                        ? Border.all(color: Colors.redAccent)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _controller,
                        minLines: 8,
                        maxLines: null,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.5,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      ),
                      if (_parseError != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          _parseError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: _cancelEdit,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _apply(context),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightGrey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    raw,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                      color: Colors.white70,
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
