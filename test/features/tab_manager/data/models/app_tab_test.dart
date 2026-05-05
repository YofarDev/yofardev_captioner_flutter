import 'package:flutter_test/flutter_test.dart';
import 'package:yofardev_captioner/features/tab_manager/data/models/app_tab.dart';

void main() {
  group('AppTab', () {
    test('value equality holds for identical tabs', () {
      const AppTab tab1 = AppTab(id: 'a', folderPath: '/photos', displayName: 'Photos');
      const AppTab tab2 = AppTab(id: 'a', folderPath: '/photos', displayName: 'Photos');

      expect(tab1, equals(tab2));
      expect(tab1.hashCode, equals(tab2.hashCode));
    });

    test('value equality fails for different tabs', () {
      const AppTab tab1 = AppTab(id: 'a', folderPath: '/photos');
      const AppTab tab2 = AppTab(id: 'b', folderPath: '/photos');

      expect(tab1, isNot(equals(tab2)));
    });

    test('copyWith creates a new instance with updated fields', () {
      const AppTab original = AppTab(id: 'a', folderPath: '/photos', displayName: 'Photos');
      final AppTab updated = original.copyWith(displayName: 'Vacation');

      expect(updated.id, equals('a'));
      expect(updated.folderPath, equals('/photos'));
      expect(updated.displayName, equals('Vacation'));
      expect(identical(original, updated), isFalse);
    });

    test('copyWith clears folderPath when clearFolderPath is true', () {
      const AppTab tab = AppTab(id: 'a', folderPath: '/photos');
      final AppTab cleared = tab.copyWith(clearFolderPath: true);

      expect(cleared.folderPath, isNull);
      expect(cleared.id, equals('a'));
    });

    test('props include all fields', () {
      const AppTab tab = AppTab(id: 'a', folderPath: '/photos', displayName: 'Photos');

      expect(tab.props, equals(<Object?>['a', '/photos', 'Photos']));
    });

    test('clearFolderPath takes precedence over folderPath', () {
      const AppTab tab = AppTab(id: 'a', folderPath: '/old');
      final AppTab result = tab.copyWith(folderPath: '/new', clearFolderPath: true);

      expect(result.folderPath, isNull);
    });

    test('defaults displayName to New Tab', () {
      const AppTab tab = AppTab(id: 'a');

      expect(tab.displayName, equals('New Tab'));
      expect(tab.folderPath, isNull);
    });
  });
}
