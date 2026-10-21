import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/models/app_image.dart';
import '../../../../helpers/image_operations_helper.dart';
import '../../../image_list/image_list.dart';

part 'image_operations_state.dart';

class ImageOperationsCubit extends Cubit<ImageOperationsState> {
  final ImageOperationsHelper _imageOperationsHelper;
  final CaptionSessionService _session;

  ImageOperationsCubit(this._session, {ImageOperationsHelper? helper})
    : _imageOperationsHelper =
          helper ?? ImageOperationsHelper(session: _session),
      super(const ImageOperationsState());

  void renameAllFiles() async {
    final String? folderPath = _session.state.folderPath;
    if (folderPath == null) {
      return;
    }
    if (state.error != null) {
      emit(state.copyWith(clearError: true));
    }
    await _session.onFolderPicked(folderPath, force: true);
    if (isClosed) return;
    final Either<Failure, void> result = await _imageOperationsHelper
        .renameAllFiles(folderPath);
    if (isClosed) return;
    result.fold(
      (Failure f) {
        if (isClosed) return;
        emit(
          state.copyWith(
            status: ImageOperationsStatus.failure,
            error: failureMessage(f),
          ),
        );
      },
      (void _) async {
        if (isClosed) return;
        await _session.onFolderPicked(folderPath, force: true);
      },
    );
  }

  Future<void> exportAsArchive(
    String folderPath,
    List<AppImage> images,
    String category,
  ) async {
    if (_session.state.folderPath == null) {
      return;
    }
    if (state.error != null) {
      emit(state.copyWith(clearError: true));
    }
    await _session.onFolderPicked(_session.state.folderPath!);
    if (isClosed) return;
    // Use fresh state from cubit after reload, not stale captured list
    final Either<Failure, void> result = await _imageOperationsHelper
        .exportAsArchive(
          _session.state.folderPath!,
          _session.state.images,
          category,
        );
    if (isClosed) return;
    result.fold((Failure f) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: ImageOperationsStatus.failure,
          error: failureMessage(f),
        ),
      );
    }, (void _) {});
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
      if (isClosed) {
        // Breaking cancels the subscription: the helper's async* generator
        // stops at its next yield, so no further files are converted.
        break;
      }
      processedImages++;
      _session.replaceState(newState);
      emit(state.copyWith(progress: processedImages / totalImages));
    }

    if (isClosed) return;
    await _session.saveChanges();

    emit(state.copyWith(status: ImageOperationsStatus.success));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (isClosed) return;
    _session.onFolderPicked(_session.state.folderPath!, force: true);
  }

  Future<void> cropCurrentImage(BuildContext context) async {
    final ImageListState? newState = await _imageOperationsHelper
        .cropCurrentImage(context, _session.state);
    if (isClosed) return;
    if (newState != null) {
      _session.replaceState(newState);
      _session.getSingleImageSize();
    }
  }
}
