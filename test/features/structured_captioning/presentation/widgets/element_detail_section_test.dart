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
import 'package:yofardev_captioner/core/models/llm_config.dart';
import 'package:yofardev_captioner/core/models/llm_configs.dart';
import 'package:yofardev_captioner/core/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/image_list/domain/models/image_list_state.dart';
import 'package:yofardev_captioner/features/image_list/domain/services/caption_session_service.dart';
import 'package:yofardev_captioner/features/llm_config/data/repositories/llm_config_service.dart';
import 'package:yofardev_captioner/features/llm_config/llm_config.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/repositories/structured_caption_repository.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/bloc/structured_editor_cubit.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/element_detail_section.dart';

import 'element_detail_section_test.mocks.dart';

/// Builds a bare caption session (in-memory store, pass-through filter) with
/// one seeded image so [StructuredEditorCubit] saves have a current target.
class _TestSession {
  static CaptionSessionService make() {
    final CaptionSessionService session = CaptionSessionService(
      fileStore: _NoopFileStore(),
      filterEngine: _Passthrough(),
    );
    session.adopt(
      ImageListState(
        images: <AppImage>[
          AppImage(
            id: 'x',
            image: File('x.png'),
            captions: const <String, CaptionEntry>{},
          ),
        ],
        folderPath: '/tmp',
        currentImageId: 'x',
      ),
    );
    return session;
  }
}

class _NoopFileStore implements CaptionFileStore {
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

class _Passthrough implements CaptionFilterEngine {
  @override
  List<AppImage> filter(
    List<AppImage> images, {
    required String category,
    required String query,
    required bool caseSensitive,
  }) => images;
}

/// [LlmConfigsCubit] subclass exposing a test-only emitter so we can drive
/// arbitrary states into the widget without triggering persistence or DI.
class _FakeLlmConfigsCubit extends LlmConfigsCubit {
  _FakeLlmConfigsCubit() : super(llmConfigService: LlmConfigService());

  void emitState(LlmConfigsState next) => emit(next);
}

@GenerateMocks(<Type>[StructuredCaptionRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  setUpAll(() {
    locator.registerLazySingleton<Logger>(() => Logger('TestElementDetail'));
  });

  const IdeogramCaption caption = IdeogramCaption(
    highLevelDescription: 'h',
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

  _FakeLlmConfigsCubit configsCubit({LlmConfig? selected}) {
    final _FakeLlmConfigsCubit cubit = _FakeLlmConfigsCubit();
    cubit.emitState(
      LlmConfigsState(
        llmConfigs: LlmConfigs(
          configs: selected == null ? <LlmConfig>[] : <LlmConfig>[selected],
          prompts: const <String>['p'],
          selectedConfigId: selected?.id,
          selectedPrompt: 'p',
        ),
      ),
    );
    return cubit;
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    required _FakeLlmConfigsCubit llmCubit,
    IdeogramCaption initialCaption = caption,
  }) async {
    final CaptionSessionService session = _TestSession.make();
    final StructuredEditorCubit editorCubit = StructuredEditorCubit(
      initialCaption: initialCaption,
      imageFile: File('x.png'),
      activeCategory: 'default',
      session: session,
      repository: MockStructuredCaptionRepository(),
    );
    editorCubit.selectElement(0);
    addTearDown(editorCubit.close);
    addTearDown(llmCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <SingleChildWidget>[
            BlocProvider<StructuredEditorCubit>.value(value: editorCubit),
            BlocProvider<LlmConfigsCubit>.value(value: llmCubit),
          ],
          child: const Scaffold(body: ElementDetailSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a disabled Recaption button when no config selected', (
    WidgetTester tester,
  ) async {
    await pumpSection(tester, llmCubit: configsCubit());
    final Finder btn = find.byKey(const Key('recaptionButton'));
    expect(btn, findsOneWidget);
    final FilledButton widget = tester.widget<FilledButton>(btn);
    expect(widget.onPressed, isNull);
  });

  testWidgets('enables Recaption for a localMlx config', (
    WidgetTester tester,
  ) async {
    final LlmConfig mlx = LlmConfig(
      id: 'm',
      name: 'mlx',
      model: 'mlx-vlm',
      providerType: LlmProviderType.localMlx,
    );
    await pumpSection(tester, llmCubit: configsCubit(selected: mlx));
    final FilledButton widget = tester.widget<FilledButton>(
      find.byKey(const Key('recaptionButton')),
    );
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('enables Recaption for a remote config', (
    WidgetTester tester,
  ) async {
    final LlmConfig remote = LlmConfig(
      id: 'r',
      name: 'remote',
      model: 'gpt-4o',
      providerType: LlmProviderType.remote,
    );
    await pumpSection(tester, llmCubit: configsCubit(selected: remote));
    final FilledButton widget = tester.widget<FilledButton>(
      find.byKey(const Key('recaptionButton')),
    );
    expect(widget.onPressed, isNotNull);
  });

  testWidgets('disables Recaption when element has no bbox', (
    WidgetTester tester,
  ) async {
    const IdeogramCaption noBboxCaption = IdeogramCaption(
      highLevelDescription: 'h',
      styleDescription: IdeogramStyleDescription(
        aesthetics: '',
        lighting: '',
        medium: 'photograph',
        colorPalette: <String>[],
      ),
      compositionalDeconstruction: IdeogramCompositionalDeconstruction(
        background: '',
        elements: <IdeogramElement>[
          IdeogramElement(type: 'obj', desc: 'no box'),
        ],
      ),
    );
    final LlmConfig remote = LlmConfig(
      id: 'r2',
      name: 'remote',
      model: 'gpt-4o',
      providerType: LlmProviderType.remote,
    );
    await pumpSection(
      tester,
      llmCubit: configsCubit(selected: remote),
      initialCaption: noBboxCaption,
    );
    final FilledButton widget = tester.widget<FilledButton>(
      find.byKey(const Key('recaptionButton')),
    );
    expect(widget.onPressed, isNull);
  });
}
