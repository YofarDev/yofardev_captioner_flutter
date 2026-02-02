import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';

import 'image_list_cubit_categories_test.mocks.dart';

@GenerateNiceMocks(<MockSpec<Object>>[MockSpec<AppFileUtils>()])
void main() {
  group('ImageListCubit Category Management', () {
    late ImageListCubit cubit;
    late MockAppFileUtils mockFileUtils;

    setUp(() {
      mockFileUtils = MockAppFileUtils();
      cubit = ImageListCubit(fileUtils: mockFileUtils);
    });

    test('adds new category', () {
      cubit.addCategory('tags');

      expect(cubit.state.categories, contains('tags'));
    });

    test('prevents duplicate category names', () {
      cubit.addCategory('tags');
      cubit.addCategory('tags');

      expect(cubit.state.categories.where((String c) => c == 'tags').length, 1);
    });

    test('removes category and switches active if needed', () {
      cubit.emit(cubit.state.copyWith(
        categories: <String>['default', 'tags'],
        activeCategory: 'tags',
      ));

      cubit.removeCategory('tags');

      expect(cubit.state.categories, isNot(contains('tags')));
      expect(cubit.state.activeCategory, equals('default'));
    });

    test('prevents removing last category', () {
      cubit.emit(cubit.state.copyWith(
        categories: <String>['default'],
        activeCategory: 'default',
      ));

      cubit.removeCategory('default');

      expect(cubit.state.categories, contains('default'));
    });

    test('renames category', () {
      cubit.emit(cubit.state.copyWith(
        categories: <String>['default', 'old'],
        activeCategory: 'old',
      ));

      cubit.renameCategory('old', 'new');

      expect(cubit.state.categories, contains('new'));
      expect(cubit.state.categories, isNot(contains('old')));
      expect(cubit.state.activeCategory, equals('new'));
    });

    test('prevents renaming to existing category name', () {
      cubit.emit(cubit.state.copyWith(
        categories: <String>['default', 'tags'],
      ));

      cubit.renameCategory('tags', 'default');

      // Should not create duplicate
      expect(cubit.state.categories.where((String c) => c == 'default').length, 1);
    });
  });
}
