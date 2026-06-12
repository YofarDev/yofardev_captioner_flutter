import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import '../widgets/element_detail_section.dart';
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
    return BlocProvider<StructuredEditorCubit>(
      create: (BuildContext context) => StructuredEditorCubit(
        initialCaption: IdeogramCaption.fromJson(
          jsonDecode(captionJson) as Map<String, dynamic>,
        ),
        imageFile: imageFile,
        activeCategory: activeCategory,
        imageListCubit: imageListCubit,
      ),
      child: const _StructuredEditorView(),
    );
  }
}

class _StructuredEditorView extends StatelessWidget {
  const _StructuredEditorView();

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
      ),
      body: const Row(
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

  @override
  Widget build(BuildContext context) {
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
                    const Spacer(),
                    if (_expanded)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: raw));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('JSON copied to clipboard'),
                              duration: Duration(seconds: 2),
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
