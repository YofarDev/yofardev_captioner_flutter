import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/llm_config.dart';
import '../../../../core/models/moss_conversion.dart';
import '../../../../core/models/moss_format.dart';
import '../../../../core/models/moss_layout_caption.dart';
import '../../../../core/models/structured_caption_document.dart';
import '../../../caption_session/caption_session.dart';
import '../../domain/repositories/structured_caption_repository.dart';
import '../../domain/services/layer_title_store.dart';

part 'structured_editor_state.dart';

/// Everything the structured editor cubit needs that only the opening page
/// knows. Passed to the DI factory as a single record (`param1`).
typedef StructuredEditorParams = ({
  StructuredCaptionDocument initialDocument,
  File imageFile,
  String activeCategory,
  CaptionSessionService session,
  bool showBboxText,
});

class StructuredEditorCubit extends Cubit<StructuredEditorState> {
  StructuredEditorCubit({
    required StructuredCaptionDocument initialDocument,
    required File imageFile,
    required String activeCategory,
    required CaptionSessionService session,
    required IStructuredCaptionRepository repository,
    LayerTitleStore? layerTitleStore,
    bool showBboxText = false,
  }) : _session = session,
       assert(
         initialDocument is! MossDocument || !initialDocument.isNative,
         'StructuredEditorCubit cannot open a native MOSS prompt (compiled '
         'abs_centralized/yxyx) — route callers to the refusal UI instead.',
       ),
       _repository = repository,
       _layerTitleStore = layerTitleStore ?? const LayerTitleStore(),
       super(
         StructuredEditorState(
           caption: initialDocument is MossDocument
               ? mossIdeogramView(initialDocument.caption)
               : (initialDocument as IdeogramDocument).caption,
           imageFile: imageFile,
           activeCategory: activeCategory,
           format: initialDocument.format,
           showBboxText: showBboxText,
           mossMeta: initialDocument is MossDocument
               ? initialDocument.caption.summary.meta
               : const <String>[],
           mossCanvas: initialDocument is MossDocument
               ? initialDocument.caption.summary.canvas
               : null,
           mossWidth: initialDocument is MossDocument
               ? initialDocument.caption.width
               : 1024,
           mossHeight: initialDocument is MossDocument
               ? initialDocument.caption.height
               : 1024,
           lockedIndices: Set<int>.from(
             Iterable<int>.generate(
               (initialDocument is MossDocument
                       ? mossIdeogramView(initialDocument.caption)
                       : (initialDocument as IdeogramDocument).caption)
                   .compositionalDeconstruction
                   .elements
                   .length,
             ),
           ),
         ),
       ) {
    _mossItems = _initialMossItems(initialDocument);
    _loadTitles();
  }

  /// Builds the authoritative item list for the opening document. MOSS
  /// drafts keep their parsed items verbatim (tags, character labels,
  /// exact pixel boxes); Ideogram starting points derive items from the
  /// normalized elements projected onto the working canvas.
  List<MossItem> _initialMossItems(StructuredCaptionDocument document) {
    if (document is MossDocument) {
      return List<MossItem>.of(document.caption.items);
    }
    final IdeogramCaption caption = (document as IdeogramDocument).caption;
    return _deriveMossItems(caption, state.mossWidth, state.mossHeight);
  }

  List<MossItem> _deriveMossItems(
    IdeogramCaption caption,
    int width,
    int height,
  ) {
    return caption.compositionalDeconstruction.elements
        .map(
          (IdeogramElement e) => MossItem(
            label: e.type == 'text' ? 'text' : 'object',
            caption: e.desc,
            text: e.type == 'text' ? (e.text ?? '') : null,
            bbox: e.bbox == null
                ? null
                : normalizedToPixelBbox(e.bbox!, width: width, height: height),
            palette: e.colorPalette ?? const <String>[],
          ),
        )
        .toList();
  }

  final CaptionSessionService _session;
  final IStructuredCaptionRepository _repository;
  final LayerTitleStore _layerTitleStore;
  final Logger _logger = Logger('StructuredEditorCubit');

  /// MOSS-only: the authoritative per-item list, index-aligned with the
  /// editable Ideogram view's elements. Each entry owns the item's stored
  /// geometry (`bbox` in top-left pixels) and metadata (`label`, `tags`) —
  /// text-only edits never touch it, so boxes survive repeated saves without
  /// round-trip rounding. List-shape mutations (add/duplicate/remove/move/
  /// replace) keep it aligned; geometry mutations go through
  /// [updateElementBbox], which reprojects only the edited item.
  List<MossItem> _mossItems = <MossItem>[];
  Timer? _debounceTimer;
  bool _isDirty = false;
  bool _titlesMutated = false;
  Future<void>? _titleSaveInFlight;
  Future<void>? _recaptionInFlight;
  Future<void>? _recaptionStyleInFlight;
  Future<void>? _samComputeInFlight;

  // -- Description --

  void updateHighLevelDescription(String value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(highLevelDescription: value),
      ),
    );
    _scheduleSave();
  }

  // -- Style --

  void updateAesthetics(String value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          styleDescription: state.caption.styleDescription.copyWith(
            aesthetics: value,
          ),
        ),
      ),
    );
    _scheduleSave();
  }

  void updateLighting(String value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          styleDescription: state.caption.styleDescription.copyWith(
            lighting: value,
          ),
        ),
      ),
    );
    _scheduleSave();
  }

  void updateMedium(String value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          styleDescription: state.caption.styleDescription.copyWith(
            medium: value,
          ),
        ),
      ),
    );
    _scheduleSave();
  }

  void updatePhoto(String? value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          styleDescription: state.caption.styleDescription.copyWith(
            photo: value,
            clearPhoto: value == null,
          ),
        ),
      ),
    );
    _scheduleSave();
  }

  void updateArtStyle(String? value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          styleDescription: state.caption.styleDescription.copyWith(
            artStyle: value,
            clearArtStyle: value == null,
          ),
        ),
      ),
    );
    _scheduleSave();
  }

  void updateStyleColorPalette(List<String> palette) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          styleDescription: state.caption.styleDescription.copyWith(
            colorPalette: palette,
          ),
        ),
      ),
    );
    _scheduleSave();
  }

  // -- Background --

  void updateBackground(String value) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(background: value),
        ),
      ),
    );
    _scheduleSave();
  }

  // -- Raw JSON --

  /// Replaces the entire caption from a raw JSON edit. Clears selection since
  /// element indices may no longer be valid.
  // ponytail: hiddenElementIndices left as-is; stale refs are harmless and
  // remapping on a full replace isn't worth the diff.
  void replaceCaption(IdeogramCaption caption) {
    replaceDocument(IdeogramDocument(caption: caption));
  }

  /// Replaces the whole document (raw-JSON edit path). For Ideogram the new
  /// caption becomes the working view; for MOSS the new layout replaces both
  /// the original (tag/label source) and the working view.
  void replaceDocument(StructuredCaptionDocument document) {
    _invalidateSamCache();
    if (document is MossDocument) {
      // Strict re-validation of the replacement: known native markers AND
      // unknown combinations / missing canvases / malformed fields are all
      // refused — never coerced through lenient fromJson defaults.
      final ({
        MossLayoutCaption? caption,
        List<MossFormatDiagnostic> diagnostics,
      })
      strict = parseMossDraft(document.caption.toJsonString());
      if (strict.caption == null) {
        _logger.warning(
          'replaceDocument refused invalid MOSS input: '
          '${strict.diagnostics.first}',
        );
        emit(
          state.copyWith(
            status: StructuredEditorStatus.error,
            error: 'Replacement rejected: ${strict.diagnostics.first.message}',
          ),
        );
        return;
      }
    }
    if (document is MossDocument) {
      // The replacement layout owns geometry and metadata wholesale — the
      // stale original item list must not leak into serialization.
      _mossItems = List<MossItem>.of(document.caption.items);
      emit(
        state.copyWith(
          caption: mossIdeogramView(document.caption),
          format: CaptionFormat.moss,
          mossMeta: document.caption.summary.meta,
          mossCanvas: document.caption.summary.canvas,
          mossWidth: document.caption.width,
          mossHeight: document.caption.height,
          clearSelection: true,
        ),
      );
    } else if (document is IdeogramDocument) {
      _mossItems = _deriveMossItems(
        document.caption,
        state.mossWidth,
        state.mossHeight,
      );
      emit(
        state.copyWith(
          caption: document.caption,
          format: CaptionFormat.ideogram,
          clearSelection: true,
        ),
      );
    }
    _scheduleSave();
  }

  // -- MOSS summary fields --

  void updateMossMeta(List<String> meta) {
    emit(state.copyWith(mossMeta: meta));
    _scheduleSave();
  }

  void updateMossCanvas(String? canvas) {
    emit(state.copyWith(mossCanvas: canvas, clearMossCanvas: canvas == null));
    _scheduleSave();
  }

  /// Edits the declared annotation canvas. This changes the annotation
  /// frame only — it never resizes the underlying image.
  ///
  /// [rescaleBoxes] = true treats the edit as an intentional annotation-frame
  /// rescale: every stored box is scaled by width/height ratio and clamped.
  /// false (default) keeps every stored box pixel-exact; the frame moves
  /// around it. Silently rescaling on unrelated edits is exactly the
  /// geometry drift this editor must not do.
  void updateMossSize({int? width, int? height, bool rescaleBoxes = false}) {
    final int oldWidth = state.mossWidth;
    final int oldHeight = state.mossHeight;
    final int newWidth = width ?? oldWidth;
    final int newHeight = height ?? oldHeight;
    if (newWidth <= 0 || newHeight <= 0) {
      // The stored frame must stay a valid annotation frame — reject instead
      // of writing an invalid canvas (old UI claimed a ×16 grid; the real
      // constraint is positivity).
      emit(
        state.copyWith(
          status: StructuredEditorStatus.error,
          error: 'Canvas dimensions must be positive integers.',
        ),
      );
      return;
    }
    List<IdeogramElement>? refreshedView;
    if (newWidth != oldWidth || newHeight != oldHeight) {
      if (rescaleBoxes) {
        _mossItems = _mossItems
            .map(
              (MossItem item) => item.copyWith(
                bbox: _scaleBbox(
                  item.bbox,
                  oldWidth,
                  oldHeight,
                  newWidth,
                  newHeight,
                ),
              ),
            )
            .toList();
      }
      // Whatever happened to the stored geometry, the normalized Ideogram
      // view must be re-derived against the NEW frame — otherwise the canvas
      // renders the old frame while saves carry the new one.
      refreshedView = _deriveViewElements(_mossItems, newWidth, newHeight);
    }
    emit(
      state.copyWith(
        mossWidth: newWidth,
        mossHeight: newHeight,
        caption: refreshedView == null
            ? null
            : state.caption.copyWith(
                compositionalDeconstruction: state
                    .caption
                    .compositionalDeconstruction
                    .copyWith(elements: refreshedView),
              ),
      ),
    );
    _scheduleSave();
  }

  /// Re-derives the normalized Ideogram view elements from the
  /// authoritative stored geometry against the given frame, preserving each
  /// element's desc/text.
  List<IdeogramElement> _deriveViewElements(
    List<MossItem> items,
    int frameWidth,
    int frameHeight,
  ) {
    return items.asMap().entries.map((MapEntry<int, MossItem> e) {
      final List<IdeogramElement> currentElements =
          state.caption.compositionalDeconstruction.elements;
      final IdeogramElement current = currentElements.length > e.key
          ? currentElements[e.key]
          : const IdeogramElement(type: 'obj', desc: '');
      final List<int>? px = e.value.bbox;
      final List<int>? normalized = px == null
          ? null
          : <int>[
              (px[1] / frameHeight * 1000).round().clamp(0, 1000),
              (px[0] / frameWidth * 1000).round().clamp(0, 1000),
              (px[3] / frameHeight * 1000).round().clamp(0, 1000),
              (px[2] / frameWidth * 1000).round().clamp(0, 1000),
            ];
      return current.copyWith(bbox: normalized, clearBbox: normalized == null);
    }).toList();
  }

  /// Scales a stored top-left pixel box between annotation frames, rounding
  /// outward (floor left/top, ceil right/bottom) and clamping to the new
  /// frame. Null boxes stay null.
  List<int>? _scaleBbox(
    List<int>? bbox,
    int oldWidth,
    int oldHeight,
    int newWidth,
    int newHeight,
  ) {
    if (bbox == null || bbox.length != 4) {
      return bbox;
    }
    final double sx = newWidth / oldWidth;
    final double sy = newHeight / oldHeight;
    final int x1 = (bbox[0] * sx).floor().clamp(0, newWidth);
    final int y1 = (bbox[1] * sy).floor().clamp(0, newHeight);
    final int x2 = (bbox[2] * sx).ceil().clamp(0, newWidth);
    final int y2 = (bbox[3] * sy).ceil().clamp(0, newHeight);
    if (x1 >= x2 || y1 >= y2) {
      return null;
    }
    return <int>[x1, y1, x2, y2];
  }

  // -- Element Selection --

  void selectElement(int index) {
    if (index < 0 ||
        index >= state.caption.compositionalDeconstruction.elements.length) {
      return;
    }
    emit(state.copyWith(selectedElementIndex: index));
  }

  void deselectElement() {
    emit(state.copyWith(clearSelection: true));
  }

  // -- Element Editing --

  void updateElementDesc(String value) {
    _invalidateSamCache();
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(desc: value);
    _emitUpdatedElements(elements);
  }

  void updateElementText(String? value) {
    _invalidateSamCache();
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(
      text: value,
      clearText: value == null,
    );
    _emitUpdatedElements(elements);
  }

  void updateElementType(String type) {
    _invalidateSamCache();
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(type: type);
    if (idx < _mossItems.length) {
      _mossItems[idx] = _mossItems[idx].copyWith(
        label: type == 'text' ? 'text' : 'object',
      );
    }
    _emitUpdatedElements(elements);
  }

  void updateElementBbox(List<int>? bbox) {
    _invalidateSamCache();
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(bbox: bbox, clearBbox: bbox == null);
    if (idx < _mossItems.length) {
      _mossItems[idx] = _mossItems[idx].copyWith(
        bbox: bbox == null
            ? null
            : normalizedToPixelBbox(
                bbox,
                width: state.mossWidth,
                height: state.mossHeight,
              ),
        clearBbox: bbox == null,
      );
    }
    _emitUpdatedElements(elements);
  }

  void updateElementColorPalette(List<String>? palette) {
    _invalidateSamCache();
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(
      colorPalette: palette,
      clearColorPalette: palette == null,
    );
    _emitUpdatedElements(elements);
  }

  // -- Single-element recaption --

  /// Recaptions the currently selected element via one VLM call.
  ///
  /// No-op if no element is selected or another recaption is in flight.
  /// Emits `status: recaptioning` + `recaptioningElementIndex` while awaiting.
  /// On success, atomically swaps the updated element in and triggers
  /// debounced save. On error, emits `status: error` and leaves the original
  /// element untouched.
  Future<void> recaptionSelectedElement({
    required LlmConfig config,
    String? instructions,
    bool cropToBbox = false,
  }) async {
    final int? selected = state.selectedElementIndex;
    if (selected == null) return;
    if (_recaptionInFlight != null) return;

    final Completer<void> inflight = Completer<void>();
    _recaptionInFlight = inflight.future;

    emit(
      state.copyWith(
        status: StructuredEditorStatus.recaptioning,
        recaptioningElementIndex: selected,
        clearError: true,
      ),
    );

    try {
      final Either<Failure, IdeogramElement> recaptionResult = await _repository
          .recaptionElement(
            config: config,
            imageFile: state.imageFile,
            currentCaption: state.caption,
            elementIndex: selected,
            instructions: instructions,
            cropToBbox: cropToBbox,
          );
      final IdeogramElement? updated = recaptionResult.getRight().toNullable();
      if (updated == null) {
        final Failure f = recaptionResult.getLeft().toNullable()!;
        _logger.warning('recaptionSelectedElement failed: $f');
        if (isClosed) {
          return;
        }
        emit(
          state.copyWith(
            status: StructuredEditorStatus.error,
            error: failureMessage(f),
            clearRecaptioning: true,
          ),
        );
        return;
      }
      final List<IdeogramElement> currentElements =
          state.caption.compositionalDeconstruction.elements;
      if (selected >= currentElements.length) {
        _logger.info(
          'recaptionSelectedElement: element $selected no longer exists; discarding result.',
        );
        if (isClosed) {
          return;
        }
        emit(
          state.copyWith(
            status: StructuredEditorStatus.saved,
            clearRecaptioning: true,
          ),
        );
      } else {
        if (isClosed) {
          return;
        }
        _invalidateSamCache();
        final List<IdeogramElement> elements = List<IdeogramElement>.from(
          currentElements,
        );
        elements[selected] = updated;
        // A recaption can replace the element's bbox — the authoritative
        // stored geometry must follow, or rendered and saved geometry would
        // diverge.
        if (selected < _mossItems.length) {
          _mossItems[selected] = _mossItems[selected].copyWith(
            bbox: updated.bbox == null
                ? null
                : normalizedToPixelBbox(
                    updated.bbox!,
                    width: state.mossWidth,
                    height: state.mossHeight,
                  ),
            clearBbox: updated.bbox == null,
            caption: updated.desc,
          );
        }
        _emitUpdatedElements(elements);
        emit(
          state.copyWith(
            status: StructuredEditorStatus.saved,
            clearRecaptioning: true,
          ),
        );
      }
    } catch (e, st) {
      _logger.warning('recaptionSelectedElement failed: $e');
      if (isClosed) {
        return;
      }
      emit(
        state.copyWith(
          status: StructuredEditorStatus.error,
          error: failureMessage(
            mapExceptionToFailure(
              e,
              stackTrace: st,
              tag: 'StructuredEditorCubit.recaptionSelectedElement',
            ),
          ),
          clearRecaptioning: true,
        ),
      );
    } finally {
      inflight.complete();
      _recaptionInFlight = null;
    }
  }

  // -- Whole-style recaption --

  /// Re-runs the VLM to regenerate ALL four style fields at once (medium,
  /// photo/art, aesthetics, lighting). The existing color palette is
  /// preserved. No-op if another style recaption is already in flight.
  ///
  /// Emits `status: recaptioning` + `recaptioningStyle: true` while awaiting.
  /// On success, swaps the [IdeogramStyleDescription] in place and triggers
  /// debounced save. On error, emits `status: error` and leaves the original
  /// style untouched.
  Future<void> recaptionStyle({required LlmConfig config}) async {
    if (_recaptionStyleInFlight != null) return;

    final Completer<void> inflight = Completer<void>();
    _recaptionStyleInFlight = inflight.future;

    emit(
      state.copyWith(
        status: StructuredEditorStatus.recaptioning,
        recaptioningStyle: true,
        clearError: true,
      ),
    );

    try {
      final Either<Failure, IdeogramStyleDescription> styleResult =
          await _repository.recaptionStyle(
            config: config,
            imageFile: state.imageFile,
            currentCaption: state.caption,
          );
      final IdeogramStyleDescription? updated = styleResult
          .getRight()
          .toNullable();
      if (updated == null) {
        final Failure f = styleResult.getLeft().toNullable()!;
        _logger.warning('recaptionStyle failed: $f');
        if (isClosed) {
          return;
        }
        emit(
          state.copyWith(
            status: StructuredEditorStatus.error,
            error: failureMessage(f),
            clearRecaptioningStyle: true,
          ),
        );
        return;
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          caption: state.caption.copyWith(styleDescription: updated),
          status: StructuredEditorStatus.saved,
          clearRecaptioningStyle: true,
        ),
      );
      _scheduleSave();
    } catch (e, st) {
      _logger.warning('recaptionStyle failed: $e');
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StructuredEditorStatus.error,
          error: failureMessage(
            mapExceptionToFailure(
              e,
              stackTrace: st,
              tag: 'StructuredEditorCubit.recaptionStyle',
            ),
          ),
          clearRecaptioningStyle: true,
        ),
      );
    } finally {
      inflight.complete();
      _recaptionStyleInFlight = null;
    }
  }

  // -- SAM3 bbox comparison toggle --

  /// Toggles between showing the saved (VLM) bboxes and SAM3-refined
  /// bboxes. When turning ON for the first time on an image, runs
  /// `computeSamBboxes` and caches the result. Subsequent toggles are
  /// instant. Concurrent calls share a single in-flight compute.
  ///
  /// Editing is disabled while [StructuredEditorState.showSamBboxes] is
  /// true — see `InteractiveBboxCanvas`. The cache is invalidated by any
  /// element mutation, so the SAM boxes never drift from the caption.
  Future<void> toggleSamBboxes() async {
    // If a compute is in flight, wait for it but don't trigger another.
    if (_samComputeInFlight != null) {
      await _samComputeInFlight;
      return;
    }

    // If turning ON and we have no cache yet, compute first.
    if (!state.showSamBboxes && state.samBboxByIndex == null) {
      await _computeSamBboxes();
      // If compute failed, leave showSamBboxes false.
      if (state.samComputeStatus != SamComputeStatus.ready) return;
    }

    emit(state.copyWith(showSamBboxes: !state.showSamBboxes));
  }

  Future<void> _computeSamBboxes() async {
    final Completer<void> completer = Completer<void>();
    _samComputeInFlight = completer.future;

    emit(state.copyWith(samComputeStatus: SamComputeStatus.computing));

    try {
      final Either<Failure, Map<int, List<int>>> result = await _repository
          .computeSamBboxes(imageFile: state.imageFile, caption: state.caption);
      if (isClosed) return;
      if (state.samComputeStatus != SamComputeStatus.computing) return;
      result.fold(
        (Failure f) {
          _logger.warning('_computeSamBboxes: compute failed: $f');
          emit(
            state.copyWith(
              samComputeStatus: SamComputeStatus.error,
              error: failureMessage(f),
            ),
          );
        },
        (Map<int, List<int>> bboxes) => emit(
          state.copyWith(
            samBboxByIndex: bboxes,
            samComputeStatus: SamComputeStatus.ready,
            clearError: true,
          ),
        ),
      );
    } finally {
      completer.complete();
      _samComputeInFlight = null;
    }
  }

  /// Clears the SAM cache. Called from every element mutator so SAM boxes
  /// never drift from the caption.
  void _invalidateSamCache() {
    if (state.samBboxByIndex == null &&
        !state.showSamBboxes &&
        state.samComputeStatus == SamComputeStatus.idle) {
      return;
    }
    emit(state.copyWith(clearSamCache: true, clearError: true));
  }

  // -- Element CRUD --

  void addElement({String type = 'obj', List<int>? bbox}) {
    _invalidateSamCache();
    final IdeogramElement newElement = IdeogramElement(
      type: type,
      bbox: bbox,
      desc: '',
    );
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    )..add(newElement);
    _mossItems.add(
      MossItem(
        label: type == 'text' ? 'text' : 'object',
        caption: '',
        bbox: bbox == null
            ? null
            : normalizedToPixelBbox(
                bbox,
                width: state.mossWidth,
                height: state.mossHeight,
              ),
      ),
    );
    final int newIndex = elements.length - 1;
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(elements: elements),
        ),
        selectedElementIndex: newIndex,
      ),
    );
    _scheduleSave();
  }

  void duplicateElement(int index) {
    _invalidateSamCache();
    final List<IdeogramElement> elements =
        state.caption.compositionalDeconstruction.elements;
    if (index < 0 || index >= elements.length) {
      return;
    }
    _titlesMutated = true;
    final List<IdeogramElement> updated = List<IdeogramElement>.from(elements)
      ..insert(index + 1, elements[index]);
    if (index < _mossItems.length) {
      _mossItems.insert(index + 1, _mossItems[index]);
    }

    final Set<int> newHidden = <int>{};
    for (final int i in state.hiddenElementIndices) {
      newHidden.add(i > index ? i + 1 : i);
    }
    if (state.hiddenElementIndices.contains(index)) {
      newHidden.add(index + 1);
    }

    final Set<int> newLocked = <int>{};
    for (final int i in state.lockedIndices) {
      newLocked.add(i > index ? i + 1 : i);
    }
    if (state.lockedIndices.contains(index)) {
      newLocked.add(index + 1);
    }

    final Map<int, String> newTitles = <int, String>{};
    state.elementTitles.forEach((int i, String t) {
      newTitles[i > index ? i + 1 : i] = t;
    });

    int? newSelection = state.selectedElementIndex;
    if (newSelection != null) {
      if (newSelection == index) {
        newSelection = index + 1;
      } else if (newSelection > index) {
        newSelection = newSelection + 1;
      }
    }

    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(elements: updated),
        ),
        selectedElementIndex: newSelection,
        clearSelection: newSelection == null,
        hiddenElementIndices: newHidden,
        lockedIndices: newLocked,
        elementTitles: newTitles,
      ),
    );
    _scheduleSave();
  }

  void removeElement(int index) {
    _invalidateSamCache();
    if (index < 0 ||
        index >= state.caption.compositionalDeconstruction.elements.length) {
      return;
    }
    _titlesMutated = true;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    )..removeAt(index);
    if (index < _mossItems.length) {
      _mossItems.removeAt(index);
    }

    int? newSelection = state.selectedElementIndex;
    if (newSelection != null) {
      if (newSelection == index) {
        // Removed the selected element → deselect
        newSelection = null;
      } else if (newSelection > index) {
        // Removed before selection → shift down
        newSelection = newSelection - 1;
      }
    }

    final Set<int> newHidden = state.hiddenElementIndices
        .where((int i) => i != index)
        .map((int i) => i > index ? i - 1 : i)
        .toSet();

    final Set<int> newLocked = state.lockedIndices
        .where((int i) => i != index)
        .map((int i) => i > index ? i - 1 : i)
        .toSet();

    final Map<int, String> newTitles = <int, String>{};
    state.elementTitles.forEach((int i, String t) {
      if (i == index) return;
      newTitles[i > index ? i - 1 : i] = t;
    });

    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(elements: elements),
        ),
        selectedElementIndex: newSelection,
        clearSelection: newSelection == null,
        hiddenElementIndices: newHidden,
        lockedIndices: newLocked,
        elementTitles: newTitles,
      ),
    );
    _scheduleSave();
  }

  // -- Reorder --

  /// Moves element [from] to [to], reordering the underlying JSON list and
  /// remapping all index-keyed UI state (selection, hidden, titles).
  void moveElement(int from, int to) {
    if (from == to) return;
    _invalidateSamCache();
    _titlesMutated = true;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    if (from < 0 ||
        from >= elements.length ||
        to < 0 ||
        to >= elements.length) {
      return;
    }
    final IdeogramElement moved = elements.removeAt(from);
    elements.insert(to, moved);
    if (from < _mossItems.length) {
      final MossItem movedItem = _mossItems.removeAt(from);
      _mossItems.insert(to, movedItem);
    }

    // Build old->new index map by performing the same move on identity slots.
    final List<int> slots = List<int>.generate(elements.length, (int i) => i);
    final int movedSlot = slots.removeAt(from);
    slots.insert(to, movedSlot);
    int oldToNew(int oldIdx) => slots.indexOf(oldIdx);

    final Map<int, String> newTitles = <int, String>{};
    state.elementTitles.forEach(
      (int oldIdx, String t) => newTitles[oldToNew(oldIdx)] = t,
    );
    final Set<int> newHidden = state.hiddenElementIndices
        .map((int oldIdx) => oldToNew(oldIdx))
        .toSet();
    final Set<int> newLocked = state.lockedIndices
        .map((int oldIdx) => oldToNew(oldIdx))
        .toSet();
    final int? newSelection = state.selectedElementIndex == null
        ? null
        : oldToNew(state.selectedElementIndex!);

    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(elements: elements),
        ),
        selectedElementIndex: newSelection,
        hiddenElementIndices: newHidden,
        lockedIndices: newLocked,
        elementTitles: newTitles,
      ),
    );
    _scheduleSave();
  }

  void toggleBboxText() {
    emit(state.copyWith(showBboxText: !state.showBboxText));
  }

  // -- Visibility --

  void toggleElementVisibility(int index) {
    final Set<int> updated = Set<int>.from(state.hiddenElementIndices);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }
    emit(state.copyWith(hiddenElementIndices: updated));
  }

  void toggleElementLock(int index) {
    final Set<int> updated = Set<int>.from(state.lockedIndices);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }
    emit(state.copyWith(lockedIndices: updated));
  }

  // -- UI-only layer titles --

  /// Sets/clears a display-only title for an element. Never persisted into the
  /// caption JSON — written to a sidecar store keyed by image path.
  void setElementTitle(int index, String title) {
    _titlesMutated = true;
    final Map<int, String> titles = Map<int, String>.from(state.elementTitles);
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      titles.remove(index);
    } else {
      titles[index] = trimmed;
    }
    emit(state.copyWith(elementTitles: titles));
    _persistTitles();
  }

  /// Loads persisted titles for this image. Guards against clobbering any
  /// title mutation that happened before the async load landed.
  Future<void> _loadTitles() async {
    final Map<int, String> loaded = await _layerTitleStore.load(
      state.imageFile.path,
    );
    if (isClosed) return;
    if (_titlesMutated) return;
    if (loaded.isEmpty) return;
    emit(state.copyWith(elementTitles: loaded));
  }

  Future<void> _persistTitles() {
    final Future<void> future = _layerTitleStore.save(
      state.imageFile.path,
      state.elementTitles,
    );
    _titleSaveInFlight = future;
    return future;
  }

  // -- Auto-save --

  /// Immediately persists any pending (debounced) changes.
  ///
  /// Call this before navigating to another image: [updateCaption] writes to
  /// the image list's *current* image, so flushing first ensures edits land on
  /// the image they belong to rather than the next one. Also awaits any
  /// in-flight recaption so its result lands on the correct element before
  /// the cubit is disposed/rebuilt, and any in-flight SAM compute so its
  /// emit doesn't fire on a closed cubit.
  Future<void> flushSave() async {
    final Future<void>? samPending = _samComputeInFlight;
    if (samPending != null) {
      await samPending;
    }
    final Future<void>? pending = _recaptionInFlight;
    if (pending != null) {
      await pending;
    }
    final Future<void>? stylePending = _recaptionStyleInFlight;
    if (stylePending != null) {
      await stylePending;
    }
    final Future<void>? titleSave = _titleSaveInFlight;
    if (titleSave != null) {
      await titleSave;
    }
    _debounceTimer?.cancel();
    if (_isDirty) {
      await _save();
    }
  }

  void _scheduleSave() {
    _isDirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _save();
    });
  }

  /// Debug/UI helper: the storage JSON the working state would save right
  /// now (used by the raw-JSON pane for MOSS, whose storage form is derived
  /// rather than held).
  String previewStoredJson() => _serialize();

  /// Serializes the working state into storage JSON. Ideogram saves the view
  /// directly; MOSS re-derives the layout from the view while preserving the
  /// original items' `label`/`tags` for surviving indices.
  String _serialize() {
    final IdeogramCaption view = state.caption;
    if (!state.isMoss) {
      return view.toJsonString();
    }
    final List<IdeogramElement> elements =
        view.compositionalDeconstruction.elements;
    final List<MossItem> items = <MossItem>[];
    for (int i = 0; i < elements.length; i++) {
      final IdeogramElement e = elements[i];
      final MossItem original = i < _mossItems.length
          ? _mossItems[i]
          : const MossItem(caption: '');
      final bool isText = e.type == 'text';
      // Geometry and tags come from the authoritative item (updated only by
      // explicit geometry/list operations), so description-only edits never
      // re-round coordinates.
      items.add(
        original.copyWith(
          label: isText ? 'text' : original.label,
          caption: e.desc,
          text: isText ? (e.text ?? '') : null,
          clearText: !isText,
          palette: e.colorPalette ?? original.palette,
        ),
      );
    }
    return MossLayoutCaption(
      width: state.mossWidth,
      height: state.mossHeight,
      summary: MossSummary(
        caption: view.highLevelDescription,
        meta: state.mossMeta,
        canvas: state.mossCanvas,
        palette: view.styleDescription.colorPalette,
      ),
      items: items,
    ).toJsonString();
  }

  Future<void> _save() async {
    try {
      final String json = _serialize();
      await _session.updateCaption(caption: json);
      await _persistTitles();
      _isDirty = false;
      if (isClosed) return;
      emit(state.copyWith(status: StructuredEditorStatus.saved));
    } catch (e, st) {
      _logger.warning('save failed: $e');
      if (isClosed) return;
      emit(
        state.copyWith(
          status: StructuredEditorStatus.error,
          error: failureMessage(
            mapExceptionToFailure(
              e,
              stackTrace: st,
              tag: 'StructuredEditorCubit.save',
            ),
          ),
        ),
      );
    }
  }

  void _emitUpdatedElements(List<IdeogramElement> elements) {
    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(elements: elements),
        ),
      ),
    );
    _scheduleSave();
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    if (_isDirty) {
      // Fire-and-forget final save
      _save();
    }
    return super.close();
  }
}
