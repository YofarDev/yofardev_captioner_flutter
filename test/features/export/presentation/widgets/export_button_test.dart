import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/export/presentation/widgets/export_button.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_operations/logic/image_operations_cubit.dart';

import 'export_button_test.mocks.dart';

@GenerateMocks(<Type>[ImageListCubit, ImageOperationsCubit])
void main() {
  /// Helper to create the widget under test with mocked cubits.
  Future<void> pumpWithCubits(
    WidgetTester tester, {
    required MockImageListCubit imageListCubit,
    required MockImageOperationsCubit imageOpsCubit,
  }) async {
    when(
      imageListCubit.stream,
    ).thenAnswer((_) => const Stream<ImageListState>.empty());
    when(
      imageOpsCubit.stream,
    ).thenAnswer((_) => const Stream<ImageOperationsState>.empty());
    when(imageOpsCubit.state).thenReturn(const ImageOperationsState());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: <BlocProvider<Cubit<Object>>>[
              BlocProvider<ImageListCubit>.value(value: imageListCubit),
              BlocProvider<ImageOperationsCubit>.value(value: imageOpsCubit),
            ],
            child: const ExportButton(),
          ),
        ),
      ),
    );
  }

  group('ExportButton Widget', () {
    testWidgets('should render export button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExportButton())),
      );

      expect(find.text('Export as Archive'), findsOneWidget);
    });

    testWidgets('should have correct button styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ExportButton())),
      );

      final Finder button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);

      final ElevatedButton elevatedButton = tester.widget<ElevatedButton>(
        button,
      );
      expect(elevatedButton.style, isNotNull);
    });

    testWidgets('tapping button opens export dialog', (
      WidgetTester tester,
    ) async {
      final MockImageListCubit mockImageListCubit = MockImageListCubit();
      final MockImageOperationsCubit mockImageOpsCubit =
          MockImageOperationsCubit();

      when(
        mockImageListCubit.state,
      ).thenReturn(const ImageListState(folderPath: '/test'));

      await pumpWithCubits(
        tester,
        imageListCubit: mockImageListCubit,
        imageOpsCubit: mockImageOpsCubit,
      );

      // Tap the export button
      await tester.tap(find.text('Export as Archive'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Export as Archive'), findsWidgets);
      expect(find.text('Select caption category to export:'), findsOneWidget);
    });

    testWidgets('dialog shows image counts', (WidgetTester tester) async {
      final MockImageListCubit mockImageListCubit = MockImageListCubit();
      final MockImageOperationsCubit mockImageOpsCubit =
          MockImageOperationsCubit();

      final AppImage imgWithCaption = AppImage(
        id: '1',
        image: File('/test/a.jpg'),
        captions: const <String, CaptionEntry>{
          'default': CaptionEntry(text: 'a cat'),
        },
      );
      final AppImage imgNoCaption = AppImage(
        id: '2',
        image: File('/test/b.jpg'),
        captions: const <String, CaptionEntry>{},
      );

      when(mockImageListCubit.state).thenReturn(
        ImageListState(
          folderPath: '/test',
          images: <AppImage>[imgWithCaption, imgNoCaption],
        ),
      );

      await pumpWithCubits(
        tester,
        imageListCubit: mockImageListCubit,
        imageOpsCubit: mockImageOpsCubit,
      );

      await tester.tap(find.text('Export as Archive'));
      await tester.pumpAndSettle();

      expect(find.text('Total images:'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('With captions:'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // Warning about missing captions
      expect(find.textContaining('images have no caption'), findsOneWidget);
    });

    testWidgets('cancel dismisses dialog', (WidgetTester tester) async {
      final MockImageListCubit mockImageListCubit = MockImageListCubit();
      final MockImageOperationsCubit mockImageOpsCubit =
          MockImageOperationsCubit();

      when(
        mockImageListCubit.state,
      ).thenReturn(const ImageListState(folderPath: '/test'));

      await pumpWithCubits(
        tester,
        imageListCubit: mockImageListCubit,
        imageOpsCubit: mockImageOpsCubit,
      );

      await tester.tap(find.text('Export as Archive'));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Select caption category to export:'), findsNothing);
    });
  });
}
