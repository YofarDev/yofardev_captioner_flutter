import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_list/presentation/widgets/image_list_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppImage buildImageWithDefaultCaption() {
    return AppImage(
      id: 'a',
      image: File('/tmp/_captioner_test.png'),
      captions: const <String, CaptionEntry>{
        'default': CaptionEntry(text: 'a cat'),
      },
      size: 100,
    );
  }

  Future<void> pumpItem(
    WidgetTester tester,
    ImageListCubit cubit,
    AppImage image,
  ) async {
    await tester.pumpWidget(
      BlocProvider<ImageListCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: BlocBuilder<ImageListCubit, ImageListState>(
              builder: (BuildContext context, ImageListState state) {
                return ImageListItem(
                  image: image,
                  isSelected: false,
                  activeCategory: state.activeCategory ?? 'default',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('ImageListItem "No caption" indicator', () {
    late ImageListCubit cubit;
    final AppImage image = buildImageWithDefaultCaption();

    setUp(() {
      cubit = ImageListCubit();
      cubit.emit(
        cubit.state.copyWith(
          images: <AppImage>[image],
          categories: <String>['default', 'tags'],
          activeCategory: 'default',
          folderPath: '/tmp',
        ),
      );
    });

    tearDown(() => cubit.close());

    testWidgets('hides indicator when active category has caption', (
      WidgetTester tester,
    ) async {
      await pumpItem(tester, cubit, image);
      expect(
        find.byIcon(Icons.edit_off),
        findsNothing,
        reason: 'default category has a caption',
      );
    });

    testWidgets('shows indicator when switched to empty category', (
      WidgetTester tester,
    ) async {
      await pumpItem(tester, cubit, image);
      expect(find.byIcon(Icons.edit_off), findsNothing);

      cubit.setActiveCategory('tags');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        find.byIcon(Icons.edit_off),
        findsOne,
        reason: 'tags category has no caption for this image',
      );
    });
  });
}
