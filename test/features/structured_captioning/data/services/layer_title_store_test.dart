import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/layer_title_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('LayerTitleStore', () {
    test('save then load round-trips int-keyed titles', () async {
      const LayerTitleStore store = LayerTitleStore();
      await store.save('img.png', <int, String>{0: 'hero', 2: 'bg'});
      expect(
        await store.load('img.png'),
        <int, String>{0: 'hero', 2: 'bg'},
      );
    });

    test('load returns empty map when nothing was saved', () async {
      expect(await const LayerTitleStore().load('none.png'), <int, String>{});
    });

    test('saving an empty map clears the key', () async {
      const LayerTitleStore store = LayerTitleStore();
      await store.save('img.png', <int, String>{1: 'x'});
      await store.save('img.png', <int, String>{});
      expect(await store.load('img.png'), <int, String>{});
    });

    test('titles are isolated per image path', () async {
      const LayerTitleStore store = LayerTitleStore();
      await store.save('a.png', <int, String>{0: 'A'});
      await store.save('b.png', <int, String>{0: 'B'});
      expect(await store.load('a.png'), <int, String>{0: 'A'});
      expect(await store.load('b.png'), <int, String>{0: 'B'});
    });

    test('corrupt stored payload degrades to empty', () async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('layerTitles:img.png', '{not json');
      expect(await const LayerTitleStore().load('img.png'), <int, String>{});
    });
  });
}
