import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:nested/nested.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/features/export/presentation/widgets/export_button.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/image_list/presentation/bloc/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_operations/presentation/bloc/image_operations_cubit.dart';

/// In-memory [CaptionFileStore]: no filesystem, no database — just enough
// ported from test/features/captioning/presentation/bloc/captioning_cubit_test.dart
/// for the session service to construct and adopt state.
class _FakeFileStore implements CaptionFileStore {
  final List<CaptionDatabase> writtenDbs = <CaptionDatabase>[];

  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) =>
      Future<
        Either<
          Failure,
          ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
        >
      >.value(
        Right<
          Failure,
          ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
        >((
          images: <AppImage>[],
          db: CaptionDatabase(
            categories: <String>['default'],
            images: <CaptionData>[],
          ),
          dbFailure: null,
        )),
      );

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async =>
      Right<Failure, CaptionDatabase>(
        CaptionDatabase(
          categories: <String>['default'],
          images: <CaptionData>[],
        ),
      );

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {
    writtenDbs.add(db);
  }

  @override
  Future<void> removeImage(File imageFile) async {}

  @override
  Future<void> writeCaptionFiles(
    String folderPath,
    List<AppImage> images,
    String category,
    String format,
  ) async {}

  @override
  Future<void> removeCaptionFiles(
    String folderPath,
    List<AppImage> images,
  ) async {}

  @override
  Future<AppImage> duplicateImage(AppImage originalImage) async =>
      originalImage;

  @override
  int compareNatural(String a, String b) => a.compareTo(b);

  @override
  Future<List<AppImage>> getImagesSize(List<AppImage> images) async => images;

  @override
  Future<AppImage> getSingleImageSize(AppImage image) async => image;
}

/// Filter engine that passes images through unchanged (unfiltered sessions).
class _StubFilterEngine implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => images;
}

void main() {
  testWidgets('renders the export button and opens the category dialog', (
    WidgetTester tester,
  ) async {
    // Build a real tab-scoped cubit pair over an in-memory session, exactly
    // like the captioning cubit tests do.
    final _FakeFileStore store = _FakeFileStore();
    final CaptionSessionService session = CaptionSessionService(
      fileStore: store,
      filterEngine: _StubFilterEngine(),
    );
    // Seed the session state via the cubit: `emit` fires onChange, which
    // calls session.adopt so the session stays the single source of truth
    // (session.adopt alone emits no snapshot and the cubit would never see
    // it — see the ImageListCubit.onChange doc comment).
    final ImageListCubit imageListCubit = ImageListCubit(session: session);
    final ImageOperationsCubit imageOperationsCubit = ImageOperationsCubit(
      session,
    );
    addTearDown(imageOperationsCubit.close);
    addTearDown(imageListCubit.close);
    addTearDown(session.dispose);
    imageListCubit.emit(
      const ImageListState(
        folderPath: '/folder',
        categories: <String>['default', 'booru'],
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <SingleChildWidget>[
          BlocProvider<ImageListCubit>.value(value: imageListCubit),
          BlocProvider<ImageOperationsCubit>.value(value: imageOperationsCubit),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ExportButton())),
        ),
      ),
    );

    expect(find.text('Export as Archive'), findsOneWidget);

    await tester.tap(find.text('Export as Archive'));
    await tester.pumpAndSettle();

    // The category dialog opened, pre-selecting the active category.
    expect(find.text('Export as Archive'), findsWidgets);
    expect(find.text('Select caption category to export:'), findsOneWidget);
    // The dropdown only renders its selected item ('default') as text until
    // a menu item is chosen, so assert the full category list on the
    // DropdownButton's items themselves.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('default'), findsWidgets);
    final DropdownButton<String> dropdown = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(
      dropdown.items!.map((DropdownMenuItem<String> item) => item.value),
      <String>['default', 'booru'],
    );
  });
}
