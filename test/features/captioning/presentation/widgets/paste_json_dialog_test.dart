import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/captioning/presentation/widgets/paste_json_dialog.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

const String _validJson =
    '{"high_level_description":"a cat","compositional_deconstruction":{"background":"sky","elements":[]}}';

AppImage _seedImage() => AppImage(
  id: 'img-1',
  image: File('/tmp/img-1.png'),
  captions: const <String, CaptionEntry>{},
  size: 100,
);

Future<void> _pumpDialog(WidgetTester tester, ImageListCubit cubit) async {
  await tester.pumpWidget(
    BlocProvider<ImageListCubit>.value(
      value: cubit,
      child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    ),
  );
  final BuildContext rootContext = tester.element(find.byType(Scaffold));
  showDialog<void>(
    context: rootContext,
    builder: (BuildContext _) => const PasteJsonDialog(),
  );
  await tester.pumpAndSettle();
}

void main() {
  late ImageListCubit cubit;

  setUp(() {
    cubit = ImageListCubit();
    cubit.emit(
      cubit.state.copyWith(
        images: <AppImage>[_seedImage()],
        categories: const <String>['default'],
        activeCategory: 'default',
        currentImageId: 'img-1',
      ),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('Apply disabled while input is invalid', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, cubit);

    await tester.enterText(find.byType(TextField), 'not json');
    await tester.pump();

    final ElevatedButton apply = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Apply'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(
      apply.onPressed,
      isNull,
      reason: 'Apply must be disabled for invalid input',
    );

    expect(
      cubit.state.images.first.captions['default']?.text ?? '',
      '',
      reason: 'No caption should have been written',
    );
  });

  testWidgets('Apply writes normalized JSON for current image', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, cubit);

    await tester.enterText(find.byType(TextField), _validJson);
    await tester.pump();

    await tester.tap(
      find.ancestor(
        of: find.text('Apply'),
        matching: find.byType(ElevatedButton),
      ),
    );
    // Let the async updateCaption + dialog close run.
    await tester.pump();
    // Advance past NotificationOverlay's auto-hide Future.delayed timer.
    await tester.pump(const Duration(seconds: 4));

    final String stored =
        cubit.state.images.first.captions['default']?.text ?? '';
    expect(stored, isNotEmpty);
    expect(stored, contains('"high_level_description":"a cat"'));
    expect(
      find.byType(PasteJsonDialog),
      findsNothing,
      reason: 'Dialog should close after applying',
    );
  });
}
