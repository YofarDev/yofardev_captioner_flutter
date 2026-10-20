import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/core/models/app_image.dart';
import 'package:yofardev_captioner/core/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/presentation/bloc/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_list/presentation/pages/images_list_view.dart';
import 'package:yofardev_captioner/features/image_list/presentation/widgets/image_list_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AppImage image = AppImage(
    id: 'a',
    image: File('/tmp/_captioner_test.png'),
    captions: const <String, CaptionEntry>{},
    size: 100,
  );

  Future<void> pumpView(WidgetTester tester, ImageListCubit cubit) async {
    await tester.pumpWidget(
      BlocProvider<ImageListCubit>.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: ImagesListView())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('ImagesListView corrupt-database warning banner', () {
    late ImageListCubit cubit;

    tearDown(() => cubit.close());

    testWidgets('shows a non-blocking banner when db could not be read', (
      WidgetTester tester,
    ) async {
      cubit = ImageListCubit();
      cubit.emit(
        const ImageListState(
          folderPath: '/tmp',
          dbLoadError: 'Database could not be read — captions were not loaded.',
        ),
      );

      await pumpView(tester, cubit);

      expect(
        find.text('Database could not be read — captions were not loaded.'),
        findsOneWidget,
      );
    });

    testWidgets('banner shows alongside loaded images', (
      WidgetTester tester,
    ) async {
      cubit = ImageListCubit();
      cubit.emit(
        ImageListState(
          folderPath: '/tmp',
          images: <AppImage>[image],
          dbLoadError: 'Database could not be read — captions were not loaded.',
        ),
      );

      await pumpView(tester, cubit);

      expect(
        find.text('Database could not be read — captions were not loaded.'),
        findsOneWidget,
      );
      expect(find.byType(ImageListItem), findsOneWidget);
    });

    testWidgets('no banner when database loaded fine', (
      WidgetTester tester,
    ) async {
      cubit = ImageListCubit();
      cubit.emit(ImageListState(folderPath: '/tmp', images: <AppImage>[image]));

      await pumpView(tester, cubit);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Database could not be read'), findsNothing);
    });
  });
}
