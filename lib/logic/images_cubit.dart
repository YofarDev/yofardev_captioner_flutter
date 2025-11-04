import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../models/app_image.dart';
import '../models/llm_config.dart';
import '../models/llm_configs.dart';
import '../repositories/caption_repository.dart';
import '../services/cache_service.dart';
import '../services/llm_config_service.dart';
import '../utils/files_utils.dart';
import '../utils/image_utils.dart';

part 'images_state.dart';

class ImagesCubit extends Cubit<ImagesState> {
  ImagesCubit() : super(const ImagesState());

  final CaptionRepository _captionRepository = CaptionRepository();

  void onInit() async {
    await CacheService.loadFolderPath().then((String? path) {
      if (path != null) {
        onFolderPicked(path);
        emit(state.copyWith(folderPath: path));
      }
    });
    await _loadLlmConfigs();
  }

  Future<void> _loadLlmConfigs() async {
    final LlmConfigs? configs = await LlmConfigService.loadLlmConfigs();
    if (configs != null) {
      emit(state.copyWith(llmConfigs: configs));
    }
  }

  void addLlmConfig(LlmConfig config) {
    final List<LlmConfig> newConfigs = <LlmConfig>[
      ...state.llmConfigs.configs,
      config,
    ];
    final String? newSelectedConfigId = state.llmConfigs.selectedConfigId;
    if (newSelectedConfigId == null) {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(
            configs: newConfigs,
            selectedConfigId: config.id,
          ),
        ),
      );
    } else {
      emit(
        state.copyWith(
          llmConfigs: state.llmConfigs.copyWith(configs: newConfigs),
        ),
      );
    }
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void updateLlmConfig(LlmConfig config) {
    final List<LlmConfig> newConfigs = state.llmConfigs.configs
        .map((LlmConfig c) => c.id == config.id ? config : c)
        .toList();
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(configs: newConfigs),
      ),
    );
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void deleteLlmConfig(String id) {
    final List<LlmConfig> newConfigs = state.llmConfigs.configs
        .where((LlmConfig c) => c.id != id)
        .toList();
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(configs: newConfigs),
      ),
    );
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void selectLlmConfig(String id) {
    emit(
      state.copyWith(
        llmConfigs: state.llmConfigs.copyWith(selectedConfigId: id),
      ),
    );
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void updatePrompt(String prompt) {
    emit(state.copyWith(llmConfigs: state.llmConfigs.copyWith(prompt: prompt)));
    LlmConfigService.saveLlmConfigs(state.llmConfigs);
  }

  void onFolderPicked(String folderPath) {
    final Directory dir = Directory(folderPath);
    final List<FileSystemEntity> files = dir.listSync();
    final List<AppImage> images = <AppImage>[];
    windowManager.setTitle("Yofardev Captioner - ${state.folderPath}");
    for (final FileSystemEntity file in files) {
      if (file is File) {
        final String extension = p.extension(file.path).toLowerCase();
        if (extension == '.jpg' ||
            extension == '.png' ||
            extension == '.jpeg' ||
            extension == '.webp') {
          final String captionPath = p.setExtension(file.path, '.txt');
          final String caption = File(captionPath).existsSync()
              ? File(captionPath).readAsStringSync()
              : '';
          images.add(
            AppImage(image: file, caption: caption, size: file.lengthSync()),
          );
        }
      }
    }
    images.sort(
      (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
    );
    emit(
      state.copyWith(images: images, sortBy: SortBy.name, sortAscending: true),
    );
    _getImagesSizeSync();
  }

  void onSortChanged(SortBy sortBy, bool sortAscending) {
    final List<AppImage> images = List<AppImage>.from(state.images);
    switch (sortBy) {
      case SortBy.name:
        images.sort(
          (AppImage a, AppImage b) => a.image.path.compareTo(b.image.path),
        );
      case SortBy.size:
        images.sort((AppImage a, AppImage b) => a.size.compareTo(b.size));
    }

    if (!sortAscending) {
      final List<AppImage> reversed = images.reversed.toList();
      images.clear();
      images.addAll(reversed);
    }

    emit(
      state.copyWith(
        images: images,
        sortBy: sortBy,
        sortAscending: sortAscending,
      ),
    );
  }

  void onSaveCaptionPressed(File file, String text) {
    unawaited(file.writeAsString(text));
  }

  void onImageSelected(int index) {
    emit(state.copyWith(currentIndex: index));
  }

  Future<void> _getImagesSizeSync() async {
    final List<AppImage> updated = <AppImage>[];
    for (final AppImage image in state.images) {
      final Size size = await ImageUtils.getImageDimensions(image.image.path);
      updated.add(
        image.copyWith(
          width: size.width.toInt(),
          height: size.height.toInt(),
          size: image.image.lengthSync(),
        ),
      );
    }
    emit(state.copyWith(images: updated));
  }

  void renameAllFiles() async {
    if (state.folderPath == null) {
      return;
    }
    await FilesUtils().renameFilesToNumbers(state.folderPath!);
    onFolderPicked(state.folderPath!);
  }

  void searchAndReplace(String search, String replace) {
    final List<AppImage> updatedImages = <AppImage>[];
    for (final AppImage image in state.images) {
      final String captionPath = p.setExtension(image.image.path, '.txt');
      final File captionFile = File(captionPath);
      final String newCaption = image.caption.replaceAll(search, replace);
      captionFile.writeAsStringSync(newCaption);
      updatedImages.add(image.copyWith(caption: newCaption));
    }
    emit(state.copyWith(images: updatedImages));
  }

  void countOccurrences(String search) {
    if (search.isEmpty) {
      emit(state.copyWith(occurrencesCount: 0));
      return;
    }
    int count = 0;
    for (final AppImage image in state.images) {
      count += search.allMatches(image.caption).length;
    }
    emit(state.copyWith(occurrencesCount: count));
  }

  Future<void> captionCurrentImage() async {
    final LlmConfig? config = state.llmConfigs.selectedConfig;
    if (config == null) {
      return;
    }

    final AppImage image = state.images[state.currentIndex];
    final String caption = await _captionRepository.getCaption(
      config,
      image,
      state.llmConfigs.prompt,
    );
    final String captionPath = p.setExtension(image.image.path, '.txt');
    await File(captionPath).writeAsString(caption);

    final List<AppImage> updatedImages = List<AppImage>.from(state.images);
    updatedImages[state.currentIndex] = image.copyWith(caption: caption);

    emit(state.copyWith(images: updatedImages));
  }

  Future<void> captionAllEmpty() async {
    final LlmConfig? config = state.llmConfigs.selectedConfig;
    if (config == null) {
      return;
    }

    final List<AppImage> imagesToCaption = state.images
        .where((AppImage image) => image.caption.isEmpty)
        .toList();

    for (final AppImage image in imagesToCaption) {
      final String caption = await _captionRepository.getCaption(
        config,
        image,
        state.llmConfigs.prompt,
      );
      final String captionPath = p.setExtension(image.image.path, '.txt');
      await File(captionPath).writeAsString(caption);

      final int index = state.images.indexOf(image);
      final List<AppImage> updatedImages = List<AppImage>.from(state.images);
      updatedImages[index] = image.copyWith(caption: caption);
      emit(state.copyWith(images: updatedImages));

      await Future<void>.delayed(Duration(milliseconds: config.delay));
    }
  }
}
