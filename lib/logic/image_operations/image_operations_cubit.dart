import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../helpers/image_operations_helper.dart';
import '../images_list/image_list_cubit.dart';

part 'image_operations_state.dart';

class ImageOperationsCubit extends Cubit<ImageOperationsState> {
  ImageOperationsCubit(this._imageListCubit)
    : super(const ImageOperationsState());

  final ImageListCubit _imageListCubit;
  final ImageOperationsHelper _imageOperationsHelper = ImageOperationsHelper();

  void renameAllFiles() async {
    if (_imageListCubit.state.folderPath == null) {
      return;
    }
    await _imageOperationsHelper.renameAllFiles(
      _imageListCubit.state.folderPath!,
    );
    _imageListCubit.onFolderPicked(_imageListCubit.state.folderPath!);
  }

  Future<void> exportAsArchive() async {
    if (_imageListCubit.state.folderPath == null) {
      return;
    }
    await _imageOperationsHelper.exportAsArchive(
      _imageListCubit.state.folderPath!,
      _imageListCubit.state.images,
    );
  }

  void convertAllImages({required String format, required int quality}) async {
    emit(
      state.copyWith(status: ImageOperationsStatus.inProgress, progress: 0.0),
    );
    final int totalImages = _imageListCubit.state.images.length;
    int processedImages = 0;

    await for (final ImageListState _
        in _imageOperationsHelper.convertAllImages(
          format: format,
          quality: quality,
          state: _imageListCubit.state,
        )) {
      processedImages++;
      emit(state.copyWith(progress: processedImages / totalImages));
    }

    emit(state.copyWith(status: ImageOperationsStatus.success));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _imageListCubit.onFolderPicked(_imageListCubit.state.folderPath!);
  }

  Future<void> cropCurrentImage(BuildContext context) async {
    final ImageListState? newState = await _imageOperationsHelper
        .cropCurrentImage(context, _imageListCubit.state);
    if (newState != null) {
      _imageListCubit.emit(newState);
    }
  }
}
