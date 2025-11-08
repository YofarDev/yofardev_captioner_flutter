import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/app_image.dart';
import '../models/llm_config.dart';
import '../repositories/caption_repository.dart';

class CaptioningRepository {
  final CaptionRepository _captionRepository = CaptionRepository();

  Future<AppImage> captionImage(
    LlmConfig config,
    AppImage image,
    String prompt,
  ) async {
    final String caption = await _captionRepository.getCaption(
      config,
      image,
      prompt,
    );
    final String captionPath = p.setExtension(image.image.path, '.txt');
    await File(captionPath).writeAsString(caption);
    return image.copyWith(caption: caption);
  }

  Stream<AppImage> captionMissing(
    List<AppImage> images,
    LlmConfig config,
    String prompt,
  ) async* {
    final List<AppImage> imagesToCaption = images
        .where((AppImage image) => image.caption.isEmpty)
        .toList();

    for (final AppImage image in imagesToCaption) {
      try {
        final AppImage updatedImage = await captionImage(config, image, prompt);
        yield updatedImage;
      } catch (e) {
        yield image.copyWith(error: e.toString());
      }
      await Future<void>.delayed(Duration(milliseconds: config.delay));
    }
  }

  Stream<AppImage> captionAll(
    List<AppImage> images,
    LlmConfig config,
    String prompt,
  ) async* {
    for (final AppImage image in images) {
      try {
        final AppImage updatedImage = await captionImage(config, image, prompt);
        yield updatedImage;
      } catch (e) {
        yield image.copyWith(error: e.toString());
      }
      await Future<void>.delayed(Duration(milliseconds: config.delay));
    }
  }
}
