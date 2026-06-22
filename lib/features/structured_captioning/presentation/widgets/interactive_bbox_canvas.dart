import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

import '../../data/models/ideogram_caption.dart';
import '../../logic/structured_editor_cubit.dart';
import '../utils/bbox_utils.dart';
import 'interactive_bbox_painter.dart';

/// Interactive canvas showing the image with editable bbox overlays.
class InteractiveBboxCanvas extends StatefulWidget {
  const InteractiveBboxCanvas({super.key});

  @override
  State<InteractiveBboxCanvas> createState() => _InteractiveBboxCanvasState();
}

class _InteractiveBboxCanvasState extends State<InteractiveBboxCanvas> {
  Size? _imageSize;

  // Drag state
  _DragMode _dragMode = _DragMode.none;
  Rect? _dragStartRect;
  Offset? _dragStartOffset;

  // New bbox drawing
  bool _isDrawingNew = false;
  Rect? _drawingRect;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final StructuredEditorState state = context
        .read<StructuredEditorCubit>()
        .state;
    try {
      final Uint8List bytes = await state.imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);
      if (image != null && mounted) {
        setState(() {
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        });
      }
    } catch (_) {
      // Leave imageSize null — fallback to image-only display
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StructuredEditorCubit, StructuredEditorState>(
      builder: (BuildContext context, StructuredEditorState state) {
        final File imageFile = state.imageFile;

        if (_imageSize == null) {
          return ColoredBox(
            color: Colors.black,
            child: Center(child: Image.file(imageFile, fit: BoxFit.contain)),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size containerSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final Rect paintedRect = getContainRect(containerSize, _imageSize!);

            return GestureDetector(
              onPanStart: (DragStartDetails details) =>
                  _onPanStart(details, paintedRect, state),
              onPanUpdate: (DragUpdateDetails details) =>
                  _onPanUpdate(details, paintedRect),
              onPanEnd: (DragEndDetails details) => _onPanEnd(state),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Image
                  ColoredBox(
                    color: Colors.black,
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  ),
                  // Bbox overlays
                  CustomPaint(
                    painter: InteractiveBboxPainter(
                      elements:
                          state.caption.compositionalDeconstruction.elements,
                      resolvedBboxes: _resolveBboxes(state),
                      hiddenIndices: state.hiddenElementIndices,
                      selectedIndex: state.selectedElementIndex,
                      paintedRect: paintedRect,
                      drawingRect: _drawingRect,
                      boxColors: kBboxColors,
                    ),
                  ),
                  if (state.showSamBboxes)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SAM3 preview — editing disabled',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.tealAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Returns the bbox to render per element, depending on the editor's
  /// display mode: SAM3 boxes when [StructuredEditorState.showSamBboxes]
  /// is on (falling back to the saved box when SAM has no entry for that
  /// element), otherwise the saved box.
  List<List<int>?> _resolveBboxes(StructuredEditorState state) {
    final List<IdeogramElement> elements =
        state.caption.compositionalDeconstruction.elements;
    final Map<int, List<int>>? sam = state.samBboxByIndex;
    final bool showSam = state.showSamBboxes;
    return List<List<int>?>.generate(elements.length, (int i) {
      final List<int>? saved = elements[i].bbox;
      if (showSam && sam != null && sam.containsKey(i)) {
        return sam[i];
      }
      return saved;
    });
  }

  void _onPanStart(
    DragStartDetails details,
    Rect paintedRect,
    StructuredEditorState state,
  ) {
    // SAM preview mode: tap-to-select only, no drag/draw/edit.
    if (state.showSamBboxes) {
      final Offset localPos = details.localPosition;
      final List<IdeogramElement> elements =
          state.caption.compositionalDeconstruction.elements;
      for (int i = elements.length - 1; i >= 0; i--) {
        final List<int>? bbox = elements[i].bbox;
        if (bbox == null) continue;
        final Rect elRect = bboxToRect(bbox, paintedRect);
        if (elRect.contains(localPos)) {
          context.read<StructuredEditorCubit>().selectElement(i);
          return;
        }
      }
      context.read<StructuredEditorCubit>().deselectElement();
      return;
    }

    final Offset localPos = details.localPosition;

    // Check if tapping on a corner handle of the selected element
    if (state.selectedElementIndex != null) {
      final IdeogramElement? element = state.selectedElement;
      if (element?.bbox != null) {
        final Rect selectedRect = bboxToRect(element!.bbox!, paintedRect);
        final _CornerHit? cornerHit = _hitTestCorner(localPos, selectedRect);
        if (cornerHit != null) {
          setState(() {
            _dragMode = _DragMode.resize;
            _dragStartRect = selectedRect;
            _dragStartOffset = localPos;
          });
          return;
        }

        // Check if tapping inside the selected element bbox
        if (selectedRect.contains(localPos)) {
          setState(() {
            _dragMode = _DragMode.move;
            _dragStartRect = selectedRect;
            _dragStartOffset = localPos;
          });
          return;
        }
      }
    }

    // Check if tapping on any other element
    final List<IdeogramElement> elements =
        state.caption.compositionalDeconstruction.elements;
    for (int i = elements.length - 1; i >= 0; i--) {
      final IdeogramElement el = elements[i];
      final List<int>? bbox = el.bbox;
      if (bbox == null) continue;
      final Rect elRect = bboxToRect(bbox, paintedRect);
      if (elRect.contains(localPos)) {
        context.read<StructuredEditorCubit>().selectElement(i);
        setState(() {
          _dragMode = _DragMode.move;
          _dragStartRect = elRect;
          _dragStartOffset = localPos;
        });
        return;
      }
    }

    // Hit nothing → start drawing new bbox
    if (paintedRect.contains(localPos)) {
      setState(() {
        _isDrawingNew = true;
        _drawingRect = Rect.fromPoints(localPos, localPos);
        _dragMode = _DragMode.none;
      });
      context.read<StructuredEditorCubit>().deselectElement();
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Rect paintedRect) {
    final Offset localPos = details.localPosition;

    switch (_dragMode) {
      case _DragMode.move:
        if (_dragStartRect != null && _dragStartOffset != null) {
          final Offset delta = localPos - _dragStartOffset!;
          Rect newRect = _dragStartRect!.shift(delta);
          newRect = _clampToPainted(newRect, paintedRect);
          final List<int> newBbox = rectToBbox(newRect, paintedRect);
          context.read<StructuredEditorCubit>().updateElementBbox(newBbox);
        }

      case _DragMode.resize:
        if (_dragStartRect != null && _dragStartOffset != null) {
          // Simplified resize: extend the rect toward the drag direction
          final Offset delta = localPos - _dragStartOffset!;
          Rect newRect = Rect.fromPoints(
            _dragStartRect!.topLeft,
            _dragStartRect!.bottomRight + delta,
          );
          newRect = _clampToPainted(newRect, paintedRect);
          final List<int> newBbox = rectToBbox(newRect, paintedRect);
          context.read<StructuredEditorCubit>().updateElementBbox(newBbox);
        }

      case _DragMode.none:
        if (_isDrawingNew) {
          setState(() {
            final Offset clamped = _clampOffset(localPos, paintedRect);
            _drawingRect = Rect.fromPoints(_drawingRect!.topLeft, clamped);
          });
        }
    }
  }

  void _onPanEnd(StructuredEditorState state) {
    if (_isDrawingNew && _drawingRect != null) {
      // Only create element if drawn rect is large enough
      if (_drawingRect!.width > 10 && _drawingRect!.height > 10) {
        final Rect paintedRect = getContainRect(
          Size(context.size!.width, context.size!.height),
          _imageSize!,
        );
        final List<int> bbox = rectToBbox(_drawingRect!, paintedRect);
        context.read<StructuredEditorCubit>().addElement(bbox: bbox);
      }
    }

    setState(() {
      _dragMode = _DragMode.none;
      _dragStartRect = null;
      _dragStartOffset = null;
      _isDrawingNew = false;
      _drawingRect = null;
    });
  }

  Rect _clampToPainted(Rect rect, Rect painted) {
    return Rect.fromLTRB(
      rect.left.clamp(painted.left, painted.right),
      rect.top.clamp(painted.top, painted.bottom),
      rect.right.clamp(painted.left, painted.right),
      rect.bottom.clamp(painted.top, painted.bottom),
    );
  }

  Offset _clampOffset(Offset offset, Rect painted) {
    return Offset(
      offset.dx.clamp(painted.left, painted.right),
      offset.dy.clamp(painted.top, painted.bottom),
    );
  }

  _CornerHit? _hitTestCorner(Offset pos, Rect rect) {
    const double tolerance = 10.0;
    // Corners: top-left, top-right, bottom-left, bottom-right
    if ((pos - rect.topLeft).distance <= tolerance) {
      return _CornerHit.topLeft;
    }
    if ((pos - rect.topRight).distance <= tolerance) {
      return _CornerHit.topRight;
    }
    if ((pos - rect.bottomLeft).distance <= tolerance) {
      return _CornerHit.bottomLeft;
    }
    if ((pos - rect.bottomRight).distance <= tolerance) {
      return _CornerHit.bottomRight;
    }
    return null;
  }
}

enum _DragMode { none, move, resize }

enum _CornerHit { topLeft, topRight, bottomLeft, bottomRight }
