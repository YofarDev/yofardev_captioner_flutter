import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../helpers/image_operations_helper.dart';
import '../../image_list/data/models/app_image.dart';
import '../../image_list/logic/image_list_cubit.dart';

part 'image_operations_state.dart';

class ImageOperationsCubit extends Cubit<ImageOperationsState> {
  late final ImageOperationsHelper _imageOperationsHelper;

  ImageOperationsCubit(this._imageListCubit)
    : super(const ImageOperationsState()) {
    _imageOperationsHelper = ImageOperationsHelper(
      imageListCubit: _imageListCubit,
    );
  }

  final ImageListCubit _imageListCubit;

  void renameAllFiles() async {
    if (_imageListCubit.state.folderPath == null) {
      return;
    }
    await _imageListCubit.onFolderPicked(_imageListCubit.state.folderPath!);
    await _imageOperationsHelper.renameAllFiles(
      _imageListCubit.state.folderPath!,
    );
    _imageListCubit.onFolderPicked(
      _imageListCubit.state.folderPath!,
      force: true,
    );
  }

  Future<void> exportAsArchive(
    String folderPath,
    List<AppImage> images,
    String category,
  ) async {
    if (_imageListCubit.state.folderPath == null) {
      return;
    }
    await _imageListCubit.onFolderPicked(_imageListCubit.state.folderPath!);
    // Use fresh state from cubit after reload, not stale captured list
    await _imageOperationsHelper.exportAsArchive(
      _imageListCubit.state.folderPath!,
      _imageListCubit.state.images,
      category,
    );
  }

  void convertAllImages({required String format, required int quality}) async {
    emit(
      state.copyWith(status: ImageOperationsStatus.inProgress, progress: 0.0),
    );
    final int totalImages = _imageListCubit.state.images.length;
    int processedImages = 0;

    await for (final ImageListState newState
        in _imageOperationsHelper.convertAllImages(
          format: format,
          quality: quality,
          state: _imageListCubit.state,
        )) {
      processedImages++;
      _imageListCubit.emit(newState);
      emit(state.copyWith(progress: processedImages / totalImages));
    }

    await _imageListCubit.saveChanges();

    emit(state.copyWith(status: ImageOperationsStatus.success));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _imageListCubit.onFolderPicked(
      _imageListCubit.state.folderPath!,
      force: true,
    );
  }

  Future<void> cropCurrentImage(BuildContext context) async {
    final ImageListState? newState = await _imageOperationsHelper
        .cropCurrentImage(context, _imageListCubit.state);
    if (newState != null) {
      _imageListCubit.emit(newState);
      _imageListCubit.getSingleImageSize();
    }
  }
}
