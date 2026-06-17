import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../image_list/data/models/app_image.dart';
import '../../../image_list/logic/image_list_cubit.dart';
import '../../../structured_captioning/data/models/ideogram_caption.dart';
import '../../data/models/batch_apply_template.dart';
import '../../data/models/caption_entry.dart';
import 'batch_json_apply_state.dart';

class BatchJsonApplyCubit extends Cubit<BatchJsonApplyState> {
  BatchJsonApplyCubit(this._imageListCubit)
    : super(const BatchJsonApplyInitial());

  final ImageListCubit _imageListCubit;
  Completer<void>? _cancelCompleter;

  Future<void> apply(BatchApplyTemplate template) async {
    _cancelCompleter = Completer<void>();

    final List<AppImage> allImages = _imageListCubit.state.images;

    final List<AppImage> targetImages = allImages.where((AppImage img) {
      final String category =
          _imageListCubit.state.activeCategory ?? 'default';
      final String text = img.captions[category]?.text ?? '';
      if (text.isEmpty) return true;
      return IdeogramCaption.isIdeogramJson(text);
    }).toList();

    if (targetImages.isEmpty) {
      emit(const BatchJsonApplyCompleted());
      _cancelCompleter = null;
      return;
    }

    final int total = targetImages.length;
    int processed = 0;
    final List<String> errors = <String>[];

    for (final AppImage image in targetImages) {
      if (_cancelCompleter?.isCompleted ?? false) {
        emit(const BatchJsonApplyError(message: 'Batch apply cancelled'));
        _cancelCompleter = null;
        return;
      }

      emit(BatchJsonApplyInProgress(
        processedImages: processed,
        totalImages: total,
        currentImageName: image.image.path,
      ));

      try {
        final String category =
            _imageListCubit.state.activeCategory ?? 'default';
        final String existingText = image.captions[category]?.text ?? '';

        final IdeogramCaption merged;
        if (existingText.isEmpty) {
          merged = template.toMinimalCaption();
        } else {
          final Map<String, dynamic> data =
              jsonDecode(existingText) as Map<String, dynamic>;
          final IdeogramCaption existing = IdeogramCaption.fromJson(data);
          merged = template.mergeInto(existing);
        }

        final AppImage updatedImage = image.copyWith(
          captions: <String, CaptionEntry>{
            ...image.captions,
            category: CaptionEntry(
              text: merged.toJsonString(),
              isEdited: true,
              timestamp: DateTime.now(),
            ),
          },
          lastModified: DateTime.now(),
          clearError: true,
        );

        await _imageListCubit.updateImage(image: updatedImage);
      } catch (e) {
        errors.add('${image.image.path}: $e');
      }

      processed++;
    }

    if (errors.isNotEmpty) {
      emit(BatchJsonApplyError(
        message: '${errors.length} error(s): ${errors.join('; ')}',
      ));
    } else {
      emit(const BatchJsonApplyCompleted());
    }
    _cancelCompleter = null;
  }

  void cancel() {
    _cancelCompleter?.complete();
  }
}
