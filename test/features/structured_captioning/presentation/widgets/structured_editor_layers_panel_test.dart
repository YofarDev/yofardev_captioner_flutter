import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:nested/nested.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/di/service_locator.dart';
import 'package:yofardev_captioner/core/errors/failure.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_data.dart';
import 'package:yofardev_captioner/core/models/caption_database.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/core/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/image_list/domain/models/image_list_state.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/structured_captioning/domain/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/bloc/structured_editor_cubit.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/layer_tile.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/layers_panel.dart';

import 'structured_editor_layers_panel_test.mocks.dart';

/// Structured-editor open → edit → save flow, exercised through the editor's
/// layers panel. The full [StructuredEditorPage] pumps real `Image.file`
/// canvases whose decoder deadlocks the widget-test fake-async zone, so the
/// page shell itself is not pumped here; the cubit/panel pair is exactly the
/// state+view the page orchestrates.
@GenerateMocks(<Type>[IStructuredCaptionRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // StructuredEditorCubit (and its repository defaults) pull their Logger
  // from the locator.
  setUpAll(() {
    locator.registerLazySingleton<Logger>(() => Logger('TestEditorSaveFlow'));
  });

  tearDownAll(() async {
    await locator.reset();
  });

  const IdeogramCaption caption = IdeogramCaption(
    highLevelDescription: 'initial description',
    styleDescription: IdeogramStyleDescription(
      aesthetics: '',
      lighting: '',
      medium: 'photograph',
      colorPalette: <String>[],
    ),
    compositionalDeconstruction: IdeogramCompositionalDeconstruction(
      background: '',
      elements: <IdeogramElement>[
        IdeogramElement(
          type: 'obj',
          desc: 'thing',
          bbox: <int>[10, 10, 90, 90],
        ),
      ],
    ),
  );

  Future<(CaptionSessionService, StructuredEditorCubit)> pumpEditor(
    WidgetTester tester,
  ) async {
    final CaptionSessionService session = CaptionSessionService(
      fileStore: _NoopFileStore(),
      filterEngine: const _PassthroughFilter(),
    );
    final ImageListState seed = ImageListState(
      images: <AppImage>[
        AppImage(
          id: 'shot',
          image: File('/tmp/shot.png'),
          captions: <String, CaptionEntry>{
            'default': CaptionEntry(text: jsonEncode(caption.toJson())),
          },
        ),
      ],
      folderPath: '/tmp',
      currentImageId: 'shot',
    );
    final StructuredEditorCubit editorCubit = StructuredEditorCubit(
      initialCaption: caption,
      imageFile: File('/tmp/shot.png'),
      activeCategory: 'default',
      session: session,
      repository: MockIStructuredCaptionRepository(),
    );
    // Mirror what the page does after seeding the session state.
    session.adopt(seed);
    addTearDown(editorCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<StructuredEditorCubit>.value(value: editorCubit),
          ],
          child: const Scaffold(body: LayersPanel()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return (session, editorCubit);
  }

  testWidgets('opens: the layers panel renders the caption elements', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester);

    expect(find.text('thing'), findsOneWidget);
    expect(find.byType(LayerTile), findsOneWidget);
  });

  testWidgets('edits and saves the caption back into the session', (
    WidgetTester tester,
  ) async {
    final (CaptionSessionService session, StructuredEditorCubit editorCubit) =
        await pumpEditor(tester);

    editorCubit.selectElement(0);
    editorCubit.updateElementDesc('edited thing');

    // The editor debounces saves at 500ms; flush deterministically.
    await editorCubit.flushSave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final String savedText =
        session.state.images.first.captions['default']!.text;
    expect(savedText, contains('edited thing'));
    final IdeogramCaption saved = IdeogramCaption.fromJson(
      jsonDecode(savedText) as Map<String, dynamic>,
    );
    expect(
      saved.compositionalDeconstruction.elements.first.desc,
      'edited thing',
    );
  });
}

class _NoopFileStore implements CaptionFileStore {
  @override
  Future<
    Either<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >
  >
  onFolderPicked(String folderPath) async {
    return Right<
      Failure,
      ({List<AppImage> images, CaptionDatabase db, Failure? dbFailure})
    >((
      images: <AppImage>[],
      db: CaptionDatabase(categories: <String>[], images: <CaptionData>[]),
      dbFailure: null,
    ));
  }

  @override
  Future<Either<Failure, CaptionDatabase>> readDb(String folderPath) async =>
      Right<Failure, CaptionDatabase>(
        CaptionDatabase(categories: <String>[], images: <CaptionData>[]),
      );

  @override
  Future<void> writeDb(String folderPath, CaptionDatabase db) async {}

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

class _PassthroughFilter implements CaptionFilterEngine {
  const _PassthroughFilter();

  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) {
    return images;
  }
}
