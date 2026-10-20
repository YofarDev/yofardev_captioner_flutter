import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/app_image.dart';
import '../../../../helpers/image_operations_helper.dart';
import '../../../image_list/domain/services/caption_session_service.dart';
import '../../../image_list/logic/image_list_state.dart';

part 'image_operations_state.dart';

class ImageOperationsCubit extends Cubit<ImageOperationsState> {
  final ImageOperationsHelper _imageOperationsHelper;
  final CaptionSessionService _session;

  ImageOperationsCubit(this._session, {ImageOperationsHelper? helper})
    : _imageOperationsHelper =
          helper ?? ImageOperationsHelper(session: _session),
      super(const ImageOperationsState());

  void renameAllFiles() async {
    if (_session.state.folderPath == null) {
      return;
    }
    await _session.onFolderPicked(_session.state.folderPath!, force: true);
    await _imageOperationsHelper.renameAllFiles(_session.state.folderPath!);
    _session.onFolderPicked(_session.state.folderPath!, force: true);
  }

  Future<void> exportAsArchive(
    String folderPath,
    List<AppImage> images,
    String category,
  ) async {
    if (_session.state.folderPath == null) {
      return;
    }
    await _session.onFolderPicked(_session.state.folderPath!);
    // Use fresh state from cubit after reload, not stale captured list
    await _imageOperationsHelper.exportAsArchive(
      _session.state.folderPath!,
      _session.state.images,
      category,
    );
  }

  void convertAllImages({required String format, required int quality}) async {
    emit(
      state.copyWith(status: ImageOperationsStatus.inProgress, progress: 0.0),
    );
    final int totalImages = _session.state.images.length;
    int processedImages = 0;

    await for (final ImageListState newState
        in _imageOperationsHelper.convertAllImages(
          format: format,
          quality: quality,
          state: _session.state,
        )) {
      processedImages++;
      _session.replaceState(newState);
      emit(state.copyWith(progress: processedImages / totalImages));
    }

    await _session.saveChanges();

    emit(state.copyWith(status: ImageOperationsStatus.success));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _session.onFolderPicked(_session.state.folderPath!, force: true);
  }

  Future<void> cropCurrentImage(BuildContext context) async {
    final ImageListState? newState = await _imageOperationsHelper
        .cropCurrentImage(context, _session.state);
    if (newState != null) {
      _session.replaceState(newState);
      _session.getSingleImageSize();
    }
  }
}
