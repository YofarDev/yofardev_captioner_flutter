import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/captioning/data/models/caption_entry.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/image_list/presentation/widgets/tag_editor.dart';

class _FakeImageListCubit extends ImageListCubit {
  _FakeImageListCubit(AppImage image)
      : super() {
    emit(ImageListState(
      images: <AppImage>[image],
      currentImageId: image.id,
    ));
  }
}

void main() {
  testWidgets('renders chips for existing tags', (WidgetTester tester) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: <String, CaptionEntry>{},
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

    expect(find.text('sunset'), findsOneWidget);
    expect(find.text('landscape'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('Enter in the field calls addTag', (WidgetTester tester) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: <String, CaptionEntry>{},
      tags: const <String>[],
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

    await tester.enterText(find.byType(TextField), 'wide-angle');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      cubit.state.images.first.tags,
      <String>['wide-angle'],
    );
    expect(find.text('wide-angle'), findsOneWidget);
  });

  testWidgets('tapping a chip X calls removeTag', (WidgetTester tester) async {
    final AppImage image = AppImage(
      id: 'img-1',
      image: File('a.jpg'),
      captions: <String, CaptionEntry>{},
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

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(cubit.state.images.first.tags, <String>[]);
  });

  testWidgets('renders nothing when no image selected',
      (WidgetTester tester) async {
    final ImageListCubit cubit = ImageListCubit();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ImageListCubit>.value(
          value: cubit,
          child: const Scaffold(body: TagEditor()),
        ),
      ),
    );

    expect(find.text('Tags'), findsNothing);
  });
}
