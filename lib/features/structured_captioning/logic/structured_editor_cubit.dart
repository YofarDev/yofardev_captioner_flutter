import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../../../core/config/service_locator.dart';
import '../../image_list/logic/image_list_cubit.dart';
import '../../llm_config/data/models/llm_config.dart';
import '../data/models/ideogram_caption.dart';
import '../data/repositories/structured_caption_repository.dart';
import '../data/services/layer_title_store.dart';

part 'structured_editor_state.dart';

class StructuredEditorCubit extends Cubit<StructuredEditorState> {
  StructuredEditorCubit({
    required IdeogramCaption initialCaption,
    required File imageFile,
    required String activeCategory,
    required ImageListCubit imageListCubit,
    StructuredCaptionRepository? repository,
    LayerTitleStore? layerTitleStore,
  }) : _imageListCubit = imageListCubit,
       _repository = repository ?? StructuredCaptionRepository(),
       _layerTitleStore = layerTitleStore ?? const LayerTitleStore(),
       super(
         StructuredEditorState(
           caption: initialCaption,
           imageFile: imageFile,
           activeCategory: activeCategory,
         ),
       ) {
    _loadTitles();
  }

  final ImageListCubit _imageListCubit;
  final StructuredCaptionRepository _repository;
  final LayerTitleStore _layerTitleStore;
  final Logger _logger = locator<Logger>();
  Timer? _debounceTimer;
  bool _isDirty = false;
  bool _titlesMutated = false;
  Future<void>? _titleSaveInFlight;
  Future<void>? _recaptionInFlight;
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
    _invalidateSamCache();
    emit(state.copyWith(caption: caption, clearSelection: true));
    _scheduleSave();
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
      final IdeogramElement updated = await _repository.recaptionElement(
        config: config,
        imageFile: state.imageFile,
        currentCaption: state.caption,
        elementIndex: selected,
        instructions: instructions,
      );
      final List<IdeogramElement> currentElements =
          state.caption.compositionalDeconstruction.elements;
      if (selected >= currentElements.length) {
        _logger.info(
          'recaptionSelectedElement: element $selected no longer exists; discarding result.',
        );
        emit(
          state.copyWith(
            status: StructuredEditorStatus.saved,
            clearRecaptioning: true,
          ),
        );
      } else {
        _invalidateSamCache();
        final List<IdeogramElement> elements = List<IdeogramElement>.from(
          currentElements,
        );
        elements[selected] = updated;
        _emitUpdatedElements(elements);
        emit(
          state.copyWith(
            status: StructuredEditorStatus.saved,
            clearRecaptioning: true,
          ),
        );
      }
    } catch (e) {
      _logger.warning('recaptionSelectedElement failed: $e');
      emit(
        state.copyWith(
          status: StructuredEditorStatus.error,
          error: e.toString(),
          clearRecaptioning: true,
        ),
      );
    } finally {
      inflight.complete();
      _recaptionInFlight = null;
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
      final Map<int, List<int>> result = await _repository.computeSamBboxes(
        imageFile: state.imageFile,
        caption: state.caption,
      );
      if (isClosed) return;
      if (state.samComputeStatus != SamComputeStatus.computing) return;
      emit(
        state.copyWith(
          samBboxByIndex: result,
          samComputeStatus: SamComputeStatus.ready,
          clearError: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      _logger.warning('_computeSamBboxes: compute failed: $e');
      emit(
        state.copyWith(
          samComputeStatus: SamComputeStatus.error,
          error: e.toString(),
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

    final Set<int> newHidden = <int>{};
    for (final int i in state.hiddenElementIndices) {
      newHidden.add(i > index ? i + 1 : i);
    }
    if (state.hiddenElementIndices.contains(index)) {
      newHidden.add(index + 1);
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
        elementTitles: newTitles,
      ),
    );
    _scheduleSave();
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

  Future<void> _save() async {
    try {
      final String json = state.caption.toJsonString();
      await _imageListCubit.updateCaption(caption: json);
      await _persistTitles();
      _isDirty = false;
      emit(state.copyWith(status: StructuredEditorStatus.saved));
    } catch (e) {
      emit(
        state.copyWith(
          status: StructuredEditorStatus.error,
          error: e.toString(),
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
