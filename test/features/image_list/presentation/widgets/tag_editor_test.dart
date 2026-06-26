import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_list/presentation/widgets/tag_editor.dart';

class _FakeImageListCubit extends ImageListCubit {
  _FakeImageListCubit(AppImage image) : super() {
    emit(ImageListState(images: <AppImage>[image], currentImageId: image.id));
  }
}

void main() {
  testWidgets('shows +Tags button when image has no tags', (
    WidgetTester tester,
  ) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: const <String, CaptionEntry>{},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: _FakeImageListCubit(image),
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    expect(find.text('+Tags'), findsOneWidget);
  });

  testWidgets('shows +Tags (N) button when image has tags', (
    WidgetTester tester,
  ) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: const <String, CaptionEntry>{},
      tags: const <String>['sunset', 'landscape'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: _FakeImageListCubit(image),
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    expect(find.text('+Tags (2)'), findsOneWidget);
  });

  testWidgets('button opens dialog with existing tags', (
    WidgetTester tester,
  ) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: const <String, CaptionEntry>{},
      tags: const <String>['sunset'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: _FakeImageListCubit(image),
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    await tester.tap(find.text('+Tags (1)'));
    await tester.pumpAndSettle();

    expect(find.text('sunset'), findsOneWidget);
  });

  testWidgets('dialog adds tags on Enter and persists instantly', (
    WidgetTester tester,
  ) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: const <String, CaptionEntry>{},
    );
    final _FakeImageListCubit cubit = _FakeImageListCubit(image);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: cubit,
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    await tester.tap(find.text('+Tags'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'wide-angle');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('wide-angle'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(cubit.state.images.first.tags, <String>['wide-angle']);
  });

  testWidgets('dialog splits multiple comma tags in one go', (
    WidgetTester tester,
  ) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: const <String, CaptionEntry>{},
    );
    final _FakeImageListCubit cubit = _FakeImageListCubit(image);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: cubit,
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    await tester.tap(find.text('+Tags'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'red, blue,green');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(cubit.state.images.first.tags, <String>['red', 'blue', 'green']);
  });

  testWidgets('dialog remove chip persists instantly', (
    WidgetTester tester,
  ) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: const <String, CaptionEntry>{},
      tags: const <String>['sunset'],
    );
    final _FakeImageListCubit cubit = _FakeImageListCubit(image);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: cubit,
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    await tester.tap(find.text('+Tags (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('sunset'), findsNothing);
    expect(cubit.state.images.first.tags, <String>[]);
  });

  testWidgets('renders nothing when no image selected', (
    WidgetTester tester,
  ) async {
    final ImageListCubit cubit = ImageListCubit();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: cubit,
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    expect(find.text('+Tags'), findsNothing);
  });
}
