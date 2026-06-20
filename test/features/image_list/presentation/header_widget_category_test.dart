import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_list/presentation/widgets/header_widget.dart';

/// Helper to locate the header's caption-count RichText.
RichText _findCountRichText(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((RichText rt) => rt.text.toPlainText().contains('captions'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppImage buildImage({
    required String id,
    Map<String, CaptionEntry> captions = const <String, CaptionEntry>{},
  }) {
    return AppImage(
      id: id,
      image: File('/tmp/$id.png'),
      captions: captions,
      size: 100,
    );
  }

  Future<void> pumpHeader(WidgetTester tester, ImageListCubit cubit) async {
    await tester.pumpWidget(
      BlocProvider<ImageListCubit>.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: HeaderWidget())),
      ),
    );
    // Let asset images settle (they will error-fail but won't crash the pump).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('Header count respects active category', () {
    late ImageListCubit cubit;

    setUp(() {
      cubit = ImageListCubit();
      cubit.emit(
        cubit.state.copyWith(
          images: <AppImage>[
            buildImage(
              id: 'a',
              captions: <String, CaptionEntry>{
                'default': const CaptionEntry(text: 'a cat'),
              },
            ),
            buildImage(id: 'b'),
          ],
          categories: <String>['default', 'tags'],
          activeCategory: 'default',
          folderPath: '/tmp',
        ),
      );
    });

    tearDown(() => cubit.close());

    testWidgets('shows correct count for default category', (
      WidgetTester tester,
    ) async {
      await pumpHeader(tester, cubit);
      expect(_findCountRichText(tester).text.toPlainText(), contains('1 / 2'));
    });

    testWidgets('updates count when switching to empty category', (
      WidgetTester tester,
    ) async {
      await pumpHeader(tester, cubit);
      expect(_findCountRichText(tester).text.toPlainText(), contains('1 / 2'));

      cubit.setActiveCategory('tags');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(_findCountRichText(tester).text.toPlainText(), contains('0 / 2'));
    });
  });
}
