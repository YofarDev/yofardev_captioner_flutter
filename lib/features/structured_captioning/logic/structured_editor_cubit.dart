import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../image_list/logic/image_list_cubit.dart';
import '../data/models/ideogram_caption.dart';

part 'structured_editor_state.dart';

class StructuredEditorCubit extends Cubit<StructuredEditorState> {
  StructuredEditorCubit({
    required IdeogramCaption initialCaption,
    required File imageFile,
    required String activeCategory,
    required ImageListCubit imageListCubit,
  }) : _imageListCubit = imageListCubit,
       super(
         StructuredEditorState(
           caption: initialCaption,
           imageFile: imageFile,
           activeCategory: activeCategory,
         ),
       );

  final ImageListCubit _imageListCubit;
  Timer? _debounceTimer;
  bool _isDirty = false;

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
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(desc: value);
    _emitUpdatedElements(elements);
  }

  void updateElementText(String? value) {
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
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(type: type);
    _emitUpdatedElements(elements);
  }

  void updateElementBbox(List<int>? bbox) {
    if (state.selectedElementIndex == null) return;
    final int idx = state.selectedElementIndex!;
    final List<IdeogramElement> elements = List<IdeogramElement>.from(
      state.caption.compositionalDeconstruction.elements,
    );
    elements[idx] = elements[idx].copyWith(bbox: bbox, clearBbox: bbox == null);
    _emitUpdatedElements(elements);
  }

  void updateElementColorPalette(List<String>? palette) {
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

  // -- Element CRUD --

  void addElement({String type = 'obj', List<int>? bbox}) {
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

  void removeElement(int index) {
    if (index < 0 ||
        index >= state.caption.compositionalDeconstruction.elements.length) {
      return;
    }
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

    emit(
      state.copyWith(
        caption: state.caption.copyWith(
          compositionalDeconstruction: state.caption.compositionalDeconstruction
              .copyWith(elements: elements),
        ),
        selectedElementIndex: newSelection,
        hiddenElementIndices: newHidden,
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

  // -- Auto-save --

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
