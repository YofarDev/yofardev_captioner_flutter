import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/apply_structured_overrides.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/moss_format.dart';
import '../../../../core/models/moss_layout_caption.dart';
import '../../../../core/models/structured_batch_overrides.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../caption_session/caption_session.dart';
import '../../../image_list/image_list.dart';
import '../../../llm_config/llm_config.dart';
import '../bloc/structured_editor_cubit.dart';
import '../widgets/editor_primitives.dart';
import '../widgets/element_detail_section.dart';
import '../widgets/interactive_bbox_canvas.dart';
import '../widgets/layers_panel.dart';
import '../widgets/moss_summary_section.dart';
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
  bool _showBboxText = false;

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
    if (!mounted) return; // flush can complete after disposal

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
      if (detectCaptionFormat(caption) != CaptionFormat.plain) {
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
      _showBboxText = cubit?.state.showBboxText ?? false;
      _imageFile = target!.image;
      _captionJson = target.captions[widget.activeCategory]?.text ?? '';
      _imageId = target.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    // STRICT draft validation before any lenient coercion: native prompts,
    // unknown marker combinations, missing canvases, and malformed fields
    // are refused visibly instead of entering the editor with guessed
    // defaults (Codex rev-2 finding 2).
    final String? refusal = _strictDraftRefusal(_captionJson);
    if (refusal != null) {
      return _refusalScaffold(refusal);
    }
    final StructuredCaptionDocument? document =
        StructuredCaptionDocument.tryParse(_captionJson);
    return _editorFor(
      document ??
          IdeogramDocument(
            caption: IdeogramCaption.fromJson(
              jsonDecode(_captionJson) as Map<String, dynamic>,
            ),
          ),
    );
  }

  /// Returns a user-facing refusal reason when [text] is MOSS JSON that
  /// fails strict draft parsing (native prompts, unknown markers, missing
  /// canvas, malformed fields). Ideogram and plain captions pass through.
  String? _strictDraftRefusal(String text) {
    final CaptionFormat format = detectCaptionFormat(text);
    if (format != CaptionFormat.moss) {
      return null;
    }
    final ({MossLayoutCaption? caption, List<MossFormatDiagnostic> diagnostics})
    parsed = parseMossDraft(text);
    if (parsed.caption != null) {
      return null;
    }
    final MossFormatDiagnostic first = parsed.diagnostics.first;
    return switch (first.code) {
      MossDiagnosticCodes.nativeMarkersInDraftPath ||
      MossDiagnosticCodes.unsupportedMarkers =>
        'This caption uses MOSS coordinate markers that are not an editable '
            'top-left draft '
            '(${first.message}). The stored text was left unchanged.',
      MossDiagnosticCodes.missingCanvasSize =>
        'This MOSS draft declares no valid canvas dimensions. '
            'The stored text was left unchanged.',
      _ =>
        'This MOSS draft is malformed: ${first.message} '
            'The stored text was left unchanged.',
    };
  }

  Widget _refusalScaffold(String reason) {
    return Scaffold(
      backgroundColor: panelRaised,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline, color: amberWarn, size: 32),
              const SizedBox(height: 12),
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Convert or repair this caption to a top-left draft to edit '
                'it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the editor scaffold for a real draft document.
  Widget _editorFor(StructuredCaptionDocument document) {
    return BlocProvider<StructuredEditorCubit>(
      key: ValueKey<String>(_imageId),
      create: (BuildContext context) {
        // Capture the instance so [_navigate] can flush it without needing a
        // descendant [BuildContext] (the provider sits in this widget's child,
        // so the scope's own context cannot read it).
        final StructuredEditorCubit cubit = locator<StructuredEditorCubit>(
          param1: (
            initialDocument: document,
            imageFile: _imageFile,
            activeCategory: widget.activeCategory,
            session: widget.imageListCubit.session,
            showBboxText: _showBboxText,
          ),
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
        foregroundColor: textPrimary,
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
                  ? accentPink
                  : (errored ? destructive : textPrimary);

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
          // Bbox text label toggle.
          BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
            buildWhen:
                (StructuredEditorState prev, StructuredEditorState next) =>
                    prev.showBboxText != next.showBboxText,
            builder: (BuildContext context, StructuredEditorState state) {
              return IconButton(
                icon: Icon(
                  state.showBboxText ? Icons.text_fields : Icons.text_fields,
                  color: state.showBboxText ? textPrimary : textMuted,
                ),
                tooltip: state.showBboxText
                    ? 'Hide bbox labels'
                    : 'Show bbox labels',
                onPressed: () {
                  context.read<StructuredEditorCubit>().toggleBboxText();
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
                      color: textSecondary,
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
        },
        child: Focus(
          autofocus: true,
          // ponytail: Delete/Backspace handled here (not in CallbackShortcuts)
          // so a focused TextField keeps them for character editing.
          // CallbackShortcuts is an ancestor Focus and would otherwise swallow
          // the key before text entry; see flutter/shortcuts.dart.
          onKeyEvent: (FocusNode node, KeyEvent event) =>
              _handleDeleteShortcut(node, event, context),
          child: const Row(
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

  KeyEventResult _handleDeleteShortcut(
    FocusNode node,
    KeyEvent event,
    BuildContext context,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    // Let an active text field keep the keystroke for editing.
    if (_primaryFocusIsEditableText()) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyL) {
      final StructuredEditorCubit c = context.read<StructuredEditorCubit>();
      final int? idx = c.state.selectedElementIndex;
      if (idx != null) c.toggleElementLock(idx);
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.delete &&
        key != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    _removeSelectedElement(context);
    return KeyEventResult.handled;
  }

  bool _primaryFocusIsEditableText() {
    final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
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
        final StructuredEditorCubit cubit = context
            .read<StructuredEditorCubit>();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              EditorSectionHeader(
                state.isMoss ? 'Summary caption' : 'Description',
              ),
              const SizedBox(height: 10),
              EditorTextField(
                value: state.caption.highLevelDescription,
                maxLines: 4,
                onChanged: cubit.updateHighLevelDescription,
              ),
              const SizedBox(height: 20),

              // Ideogram gets style + background sections; MOSS folds both
              // into summary (meta tags / canvas / palette) and the caption.
              if (state.isMoss) ...<Widget>[
                const EditorSectionHeader('MOSS Summary'),
                const SizedBox(height: 10),
                const MossSummarySection(),
                const SizedBox(height: 20),
              ] else ...<Widget>[
                const EditorSectionHeader('Style'),
                const SizedBox(height: 10),
                const StyleEditorSection(),
                const SizedBox(height: 20),
                const EditorSectionHeader('Background'),
                const SizedBox(height: 10),
                EditorTextField(
                  value: state.caption.compositionalDeconstruction.background,
                  maxLines: 4,
                  onChanged: cubit.updateBackground,
                ),
                const SizedBox(height: 20),
              ],

              // Selected element detail
              if (state.isElementSelected) ...<Widget>[
                const ElementDetailSection(),
                const SizedBox(height: 20),
              ],

              const _JsonViewer(),
            ],
          ),
        );
      },
    );
  }
}

class _JsonViewer extends StatefulWidget {
  const _JsonViewer();

  @override
  State<_JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<_JsonViewer> {
  static final Logger _logger = Logger('StructuredEditorPage');
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
    // Raw MOSS replacements go through the STRICT draft parser: native
    // prompts, unknown markers, missing canvases, and malformed fields are
    // refused here instead of entering the editor via lenient coercion.
    final CaptionFormat rawFormat = detectCaptionFormat(_controller.text);
    if (rawFormat == CaptionFormat.moss) {
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      strict = parseMossDraft(_controller.text);
      if (strict.caption == null) {
        setState(() {
          _parseError = 'Rejected: ${strict.diagnostics.first.message}';
        });
        _logger.warning(
          'Raw MOSS replacement failed strict validation: '
          '${strict.diagnostics.first}',
        );
        return;
      }
    }
    final StructuredCaptionDocument? document =
        StructuredCaptionDocument.tryParse(_controller.text);
    if (document != null) {
      context.read<StructuredEditorCubit>().replaceDocument(document);
      setState(() {
        _editing = false;
        _parseError = null;
      });
      return;
    }
    try {
      jsonDecode(_controller.text) as Map<String, dynamic>;
    } on FormatException catch (e) {
      // The offset in e.message is actionable for a power user fixing JSON.
      setState(() => _parseError = 'Invalid JSON: ${e.message}');
    } catch (_) {
      setState(() => _parseError = 'Invalid JSON.');
    }
    _logger.warning('Caption JSON did not match a structured schema');
    setState(
      () => _parseError =
          'Invalid caption: the JSON matches neither the Ideogram nor the '
          'MOSS schema.',
    );
  }

  /// Re-derives the current MOSS JSON from the working state (the cubit
  /// persists through the same path, so this matches what a save writes).
  static String _mossPrettyJson(
    BuildContext context,
    StructuredEditorState state,
  ) {
    final String stored = context
        .read<StructuredEditorCubit>()
        .previewStoredJson();
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(stored) as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    final StructuredBatchOverrides overrides = context
        .select<LlmConfigsCubit, StructuredBatchOverrides>(
          (LlmConfigsCubit c) => c.state.llmConfigs.structuredBatchOverrides,
        );
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final String raw = state.isMoss
            ? _mossPrettyJson(context, state)
            : const JsonEncoder.withIndent(
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
                  color: panelRaised,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _expanded ? Icons.expand_less : Icons.code,
                      size: 18,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Raw JSON',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
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
                          color: accentPink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'overrides',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: lightPink,
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
                            color: panelDark,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    InkWell(
                      onTap: () {
                        final Map<String, dynamic> copyJson = state.isMoss
                            ? jsonDecode(_mossPrettyJson(context, state))
                                  as Map<String, dynamic>
                            : applyStructuredOverrides(
                                state.caption,
                                overrides,
                              ).toJson();
                        final String copyText = const JsonEncoder.withIndent(
                          '  ',
                        ).convert(copyJson);
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
                          color: panelDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.copy,
                          size: 16,
                          color: textSecondary,
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
                    color: panelRaised,
                    borderRadius: BorderRadius.circular(8),
                    border: _parseError != null
                        ? Border.all(color: destructive)
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
                          color: textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                      if (_parseError != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          _parseError!,
                          style: const TextStyle(
                            color: destructive,
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
                    color: panelRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    raw,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.5,
                      color: textSecondary,
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
