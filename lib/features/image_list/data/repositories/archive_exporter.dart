import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/models/app_image.dart';
import '../../../../core/models/caption_entry.dart';
import '../../../../core/models/ideogram_caption.dart';
import '../../../../core/models/moss_layout_caption.dart';

/// Builds the ZIP archive export (images + per-category caption sidecars)
/// and hands it to the platform save dialog. file_picker v13 writes the
/// provided bytes itself when the user confirms a path; the returned Uri is
/// informational.
class ArchiveExporter {
  const ArchiveExporter();

  static final Logger _logger = Logger('ArchiveExporter');

  /// `<folder>.zip` for the default category, `<folder>-<category>.zip`
  /// otherwise.
  @visibleForTesting
  static String archiveFileName(String folderPath, String category) {
    final String baseFileName = p.basename(folderPath);
    return category == 'default'
        ? '$baseFileName.zip'
        : '$baseFileName-$category.zip';
  }

  Future<Either<Failure, void>> exportAsArchive(
    String folderPath,
    List<AppImage> images,
    String category,
  ) async {
    try {
      final String? downloadsPath = await getDownloadsDirectory().then(
        (Directory? dir) => dir?.path,
      );
      final String fileName = archiveFileName(folderPath, category);

      // ponytail: build zip to temp file first; file_picker v13 saveFile
      // requires bytes upfront and writes them itself (no path-only mode).
      final String tempPath = p.join(Directory.systemTemp.path, fileName);
      final ZipFileEncoder encoder = ZipFileEncoder();
      encoder.create(tempPath);

      // Add images and their captions
      for (final AppImage image in images) {
        await encoder.addFile(image.image);

        final CaptionEntry? captionEntry = image.captions[category];
        if (captionEntry != null && captionEntry.text.isNotEmpty) {
          final bool isJson =
              IdeogramCaption.isIdeogramJson(captionEntry.text) ||
              MossLayoutCaption.isMossJson(captionEntry.text);
          final List<int> captionBytes = utf8.encode(captionEntry.text);
          final ArchiveFile archiveFile = ArchiveFile(
            p.setExtension(
              p.basename(image.image.path),
              isJson ? '.json' : '.txt',
            ),
            captionBytes.length,
            captionBytes,
          );
          encoder.addArchiveFile(archiveFile);
        }
      }

      // Close the zip file first to finalize the archive
      encoder.close();

      final Uint8List zipBytes = await File(tempPath).readAsBytes();
      await File(tempPath).delete();

      final Uri? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Please select an output file',
        fileName: fileName,
        initialDirectory: downloadsPath,
        bytes: zipBytes,
      );
      if (outputFile == null) {
        _logger.fine('exportAsArchive: user cancelled the save dialog');
      }
      return const Right<Failure, void>(null);
    } catch (e, st) {
      return Left<Failure, void>(
        mapExceptionToFailure(
          e,
          stackTrace: st,
          tag: 'ArchiveExporter.exportAsArchive',
        ),
      );
    }
  }
}
