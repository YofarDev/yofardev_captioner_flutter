import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nested/nested.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_configs.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';
import 'package:yofardev_captioner/features/llm_config/logic/llm_configs_cubit.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/logic/structured_editor_cubit.dart';
import 'package:yofardev_captioner/features/structured_captioning/presentation/widgets/element_detail_section.dart';

import 'element_detail_section_test.mocks.dart';

/// [LlmConfigsCubit] subclass exposing a test-only emitter so we can drive
/// arbitrary states into the widget without triggering persistence or DI.
class _FakeLlmConfigsCubit extends LlmConfigsCubit {
  _FakeLlmConfigsCubit() : super();

  void emitState(LlmConfigsState next) => emit(next);
}

@GenerateMocks(<Type>[ImageListCubit])
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
    final MockImageListCubit mockImageList = MockImageListCubit();
    when(
      mockImageList.updateCaption(caption: anyNamed('caption')),
    ).thenAnswer((_) async {});

    final StructuredEditorCubit editorCubit = StructuredEditorCubit(
      initialCaption: initialCaption,
      imageFile: File('x.png'),
      activeCategory: 'default',
      imageListCubit: mockImageList,
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
