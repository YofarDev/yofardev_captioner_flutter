import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/models/ideogram_caption.dart';
import 'package:yofardev_captioner/features/structured_captioning/logic/structured_editor_cubit.dart';

import 'structured_editor_cubit_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  IdeogramCaption baseCaption() => const IdeogramCaption(
    highLevelDescription: 'hld',
    styleDescription: IdeogramStyleDescription(
      aesthetics: 'a',
      lighting: 'l',
      medium: 'photograph',
      colorPalette: <String>['#000000'],
    ),
    compositionalDeconstruction: IdeogramCompositionalDeconstruction(
      background: 'a plain wall',
      elements: <IdeogramElement>[
        IdeogramElement(type: 'obj', desc: 'first'),
        IdeogramElement(type: 'obj', desc: 'second'),
        IdeogramElement(type: 'obj', desc: 'third'),
      ],
    ),
  );

  group('StructuredEditorCubit', () {
    late StructuredEditorCubit cubit;
    late MockImageListCubit mockImageListCubit;

    setUpAll(() {
      locator.registerLazySingleton<Logger>(() => Logger('TestEditor'));
    });

    setUp(() {
      mockImageListCubit = MockImageListCubit();
      when(
        mockImageListCubit.updateCaption(caption: anyNamed('caption')),
      ).thenAnswer((_) async {});
      cubit = StructuredEditorCubit(
        initialCaption: baseCaption(),
        imageFile: File('img.png'),
        activeCategory: 'default',
        imageListCubit: mockImageListCubit,
      );
    });

    tearDown(() async {
      await cubit.flushSave();
      await cubit.close();
    });

    test('initial state holds caption and no selection', () {
      expect(cubit.state.caption.highLevelDescription, 'hld');
      expect(cubit.state.isElementSelected, false);
      expect(cubit.state.selectedElement, isNull);
    });

    group('style / description updates', () {
      test('updateHighLevelDescription mutates caption', () {
        cubit.updateHighLevelDescription('new description');
        expect(cubit.state.caption.highLevelDescription, 'new description');
      });

      test('updateAesthetics mutates style description', () {
        cubit.updateAesthetics('moody');
        expect(cubit.state.caption.styleDescription.aesthetics, 'moody');
      });

      test('updateLighting mutates style description', () {
        cubit.updateLighting('soft');
        expect(cubit.state.caption.styleDescription.lighting, 'soft');
      });

      test('updateMedium mutates style description', () {
        cubit.updateMedium('oil painting');
        expect(cubit.state.caption.styleDescription.medium, 'oil painting');
      });

      test('updateStyleColorPalette replaces palette', () {
        cubit.updateStyleColorPalette(const <String>['#ffffff', '#aaaaaa']);
        expect(cubit.state.caption.styleDescription.colorPalette, <String>[
          '#ffffff',
          '#aaaaaa',
        ]);
      });

      test('updatePhoto sets value, clearPhoto keeps it nullable', () {
        cubit.updatePhoto('50mm');
        expect(cubit.state.caption.styleDescription.photo, '50mm');
        cubit.updatePhoto(null);
        expect(cubit.state.caption.styleDescription.photo, isNull);
      });
    });

    group('element selection', () {
      test('selectElement sets index and resolves selectedElement', () {
        cubit.selectElement(1);
        expect(cubit.state.selectedElementIndex, 1);
        expect(cubit.state.selectedElement?.desc, 'second');
      });

      test('selectElement ignores out-of-range index', () {
        cubit.selectElement(99);
        expect(cubit.state.selectedElementIndex, isNull);
      });

      test('deselectElement clears selection', () {
        cubit.selectElement(0);
        cubit.deselectElement();
        expect(cubit.state.selectedElementIndex, isNull);
      });
    });

    group('element editing (requires selection)', () {
      test('updateElementDesc writes to selected element only', () {
        cubit.selectElement(0);
        cubit.updateElementDesc('edited first');
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[0].desc,
          'edited first',
        );
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].desc,
          'second',
        );
      });

      test('updateElementType changes type', () {
        cubit.selectElement(2);
        cubit.updateElementType('text');
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[2].type,
          'text',
        );
      });

      test('updateElementBbox sets then clears', () {
        cubit.selectElement(1);
        cubit.updateElementBbox(const <int>[10, 20, 30, 40]);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].bbox,
          <int>[10, 20, 30, 40],
        );
        cubit.updateElementBbox(null);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].bbox,
          isNull,
        );
      });

      test('editors are no-ops without selection', () {
        cubit.updateElementDesc('noop');
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[0].desc,
          'first',
        );
      });
    });

    group('element CRUD', () {
      test('addElement appends and selects the new element', () {
        cubit.addElement();
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          4,
        );
        expect(cubit.state.selectedElementIndex, 3);
      });

      test('removeElement removes the element', () {
        cubit.removeElement(1);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          2,
        );
        expect(
          cubit.state.caption.compositionalDeconstruction.elements[1].desc,
          'third',
        );
      });

      test('removeElement deselects when removing the selected element', () {
        cubit.selectElement(1);
        cubit.removeElement(1);
        expect(cubit.state.selectedElementIndex, isNull);
      });

      test(
        'removeElement shifts selection down when removing earlier element',
        () {
          cubit.selectElement(2);
          cubit.removeElement(0);
          expect(cubit.state.selectedElementIndex, 1);
        },
      );

      test('removeElement shifts hidden indices', () {
        cubit.toggleElementVisibility(2);
        expect(cubit.state.hiddenElementIndices, <int>{2});
        cubit.removeElement(0);
        expect(cubit.state.hiddenElementIndices, <int>{1});
      });

      test('removeElement ignores out-of-range index', () {
        cubit.removeElement(99);
        expect(
          cubit.state.caption.compositionalDeconstruction.elements.length,
          3,
        );
      });
    });

    group('visibility', () {
      test('toggleElementVisibility adds then removes index', () {
        cubit.toggleElementVisibility(0);
        expect(cubit.state.hiddenElementIndices, <int>{0});
        cubit.toggleElementVisibility(0);
        expect(cubit.state.hiddenElementIndices, <int>{});
      });
    });

    group('save', () {
      test('flushSave persists caption and emits saved status', () async {
        cubit.updateHighLevelDescription('dirty');
        await cubit.flushSave();

        expect(cubit.state.status, StructuredEditorStatus.saved);
        final VerificationResult verification = verify(
          mockImageListCubit.updateCaption(caption: captureAnyNamed('caption')),
        );
        verification.called(1);
        final String captured = verification.captured.single as String;
        expect(captured, contains('dirty'));
      });

      test('save emits error status when updateCaption throws', () async {
        when(
          mockImageListCubit.updateCaption(caption: anyNamed('caption')),
        ).thenThrow(Exception('disk full'));

        cubit.updateHighLevelDescription('dirty again');
        await cubit.flushSave();

        expect(cubit.state.status, StructuredEditorStatus.error);
        expect(cubit.state.error, contains('disk full'));
      });

      test('flushSave is a no-op when nothing changed', () async {
        await cubit.flushSave();
        verifyNever(
          mockImageListCubit.updateCaption(caption: anyNamed('caption')),
        );
      });
    });
  });
}
