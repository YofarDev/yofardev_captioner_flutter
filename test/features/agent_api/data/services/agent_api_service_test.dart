import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/agent_api/data/services/agent_api_service.dart';
import 'package:yofardev_captioner/features/image_list/data/models/app_image.dart';
import 'package:yofardev_captioner/features/image_list/data/repositories/app_file_utils.dart';
import 'package:yofardev_captioner/features/image_list/logic/image_list_cubit.dart';
import 'package:yofardev_captioner/features/llm_config/logic/llm_configs_cubit.dart';
import 'package:yofardev_captioner/features/tab_manager/logic/tab_manager_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding stubs HttpClient to answer 400 for every request and
  // touch no network; restore the real client so this suite can talk to the
  // loopback shelf server.
  HttpOverrides.global = null;

  const MethodChannel channel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return null;
      });

  // Valid 1x1 PNG so image decoding during folder scans doesn't error.
  final List<int> tinyPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  late Directory tempDir;
  late Directory discoveryDir;
  late AgentApiService service;
  late http.Client client;
  late int port;
  late String token;

  Map<String, String> authHeader() => <String, String>{
    'authorization': 'Bearer $token',
  };

  Uri uri(String path, [Map<String, String>? query]) => Uri.http(
    '127.0.0.1:$port',
    path,
    query,
  );

  Future<Directory> makeImageFolder(String name, List<String> filenames) async {
    final Directory folder = Directory(p.join(tempDir.path, name))
      ..createSync(recursive: true);
    for (final String filename in filenames) {
      await File(p.join(folder.path, filename)).writeAsBytes(tinyPngBytes);
    }
    return folder;
  }

  Future<http.Response> postCaption(Map<String, dynamic> body) =>
      client.post(
        uri('/api/captions'),
        headers: authHeader()
          ..['content-type'] = 'application/json',
        body: jsonEncode(body),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'agentApiPort': 0},
    );
    await locator.reset();
    tempDir = await Directory.systemTemp.createTemp('agent_api_images');
    discoveryDir = await Directory.systemTemp.createTemp('agent_api_disc');
    locator.registerLazySingleton<AppFileUtils>(AppFileUtils.new);

    service = AgentApiService(discoveryDirPath: discoveryDir.path);
    await service.start();
    port = service.port!;
    token = service.token!;
    client = http.Client();
  });

  tearDown(() async {
    client.close();
    await service.stop();
    await tempDir.delete(recursive: true);
    await discoveryDir.delete(recursive: true);
  });

  test('health responds without authentication', () async {
    final http.Response res = await client.get(uri('/api/health'));

    expect(res.statusCode, 200);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['status'], 'ok');
    expect(body['app'], 'yofardev_captioner');
    expect(body['version'], isNotNull);
  });

  test('protected endpoints reject missing or invalid token', () async {
    expect(
      (await client.get(uri('/api/prompts'))).statusCode,
      401,
    );
    expect(
      (await client.get(
        uri('/api/prompts'),
        headers: <String, String>{'authorization': 'Bearer wrong'},
      ))
          .statusCode,
      401,
    );
  });

  test('prompts come from the registered LlmConfigsCubit', () async {
    locator.registerSingleton<LlmConfigsCubit>(LlmConfigsCubit());

    final http.Response res = await client.get(
      uri('/api/prompts'),
      headers: authHeader(),
    );

    expect(res.statusCode, 200);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['prompts'] as List<dynamic>, hasLength(2));
    expect(body['selectedPrompt'], isNotNull);
  });

  test('discovery file contains port and token', () async {
    final File file = File(p.join(discoveryDir.path, 'agent-api.json'));

    expect(await file.exists(), isTrue);
    final Map<String, dynamic> body =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(body['port'], port);
    expect(body['token'], token);
  });

  test('images lists an unopened folder from disk', () async {
    final Directory folder = await makeImageFolder('alpha', <String>[
      'a.png',
      'b.png',
    ]);

    final http.Response res = await client.get(
      uri('/api/images', <String, String>{'folder': folder.path}),
      headers: authHeader(),
    );

    expect(res.statusCode, 200);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['categories'], contains('default'));
    final List<dynamic> images = body['images'] as List<dynamic>;
    expect(images, hasLength(2));
    final Map<String, dynamic> first = images.first as Map<String, dynamic>;
    expect(first['filename'], 'a.png');
    expect(first['captions'], isEmpty);
    expect(first['id'], isNull);
  });

  test('images returns 404 for a missing folder', () async {
    final http.Response res = await client.get(
      uri('/api/images', <String, String>{
        'folder': p.join(tempDir.path, 'does_not_exist'),
      }),
      headers: authHeader(),
    );

    expect(res.statusCode, 404);
  });

  test('caption write to an unopened folder persists to db.json', () async {
    final Directory folder = await makeImageFolder('beta', <String>['cat.png']);

    final http.Response res = await postCaption(<String, dynamic>{
      'folder': folder.path,
      'filename': 'cat.png',
      'text': 'a fluffy cat',
      'model': 'claude-code',
      'tags': <String>['animal'],
    });

    expect(res.statusCode, 200);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['mode'], 'file');
    expect(body['created'], isTrue);

    final Map<String, dynamic> db =
        jsonDecode(await File(p.join(folder.path, 'db.json')).readAsString())
            as Map<String, dynamic>;
    expect(db['version'], 4);
    final Map<String, dynamic> image =
        (db['images'] as List<dynamic>).single as Map<String, dynamic>;
    expect(image['filename'], 'cat.png');
    expect(image['id'], isNotNull);
    final Map<String, dynamic> entry =
        (image['captions'] as Map<String, dynamic>)['default']
            as Map<String, dynamic>;
    expect(entry['text'], 'a fluffy cat');
    expect(entry['model'], 'claude-code');
    expect(entry['isEdited'], false);
    expect(entry['timestamp'], isNotNull);
    expect(image['tags'], contains('animal'));
  });

  test('caption write merges tags into an existing db entry', () async {
    final Directory folder = await makeImageFolder('beta2', <String>['dog.png']);
    // Seed the db by writing once.
    await postCaption(<String, dynamic>{
      'folder': folder.path,
      'filename': 'dog.png',
      'text': 'first',
      'tags': <String>['animal'],
    });
    await postCaption(<String, dynamic>{
      'folder': folder.path,
      'filename': 'dog.png',
      'text': 'second',
      'tags': <String>['cute'],
    });

    final Map<String, dynamic> db =
        jsonDecode(await File(p.join(folder.path, 'db.json')).readAsString())
            as Map<String, dynamic>;
    final Map<String, dynamic> image =
        (db['images'] as List<dynamic>).single as Map<String, dynamic>;
    final Map<String, dynamic> entry =
        (image['captions'] as Map<String, dynamic>)['default']
            as Map<String, dynamic>;
    expect(entry['text'], 'second');
    expect(image['tags'], containsAll(<String>['animal', 'cute']));
  });

  test('caption write with unknown category returns 400 and valid ones',
      () async {
    final Directory folder = await makeImageFolder('gamma', <String>['x.png']);

    final http.Response res = await postCaption(<String, dynamic>{
      'folder': folder.path,
      'filename': 'x.png',
      'text': 'nope',
      'category': 'does-not-exist',
    });

    expect(res.statusCode, 400);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['categories'], contains('default'));
  });

  test('caption write for missing image returns 404', () async {
    final Directory folder = await makeImageFolder('delta', <String>['y.png']);

    final http.Response res = await postCaption(<String, dynamic>{
      'folder': folder.path,
      'filename': 'ghost.png',
      'text': 'boo',
    });

    expect(res.statusCode, 404);
  });

  test('caption write routes through the open tab cubit and persists',
      () async {
    final Directory folder = await makeImageFolder('live', <String>[
      'one.png',
      'two.png',
    ]);
    final TabManagerCubit tabManager = TabManagerCubit();
    locator.registerSingleton<TabManagerCubit>(tabManager);
    tabManager.addTab(folder.path);
    final String tabId = tabManager.state.tabs.last.id;
    final ImageListCubit imageListCubit = ImageListCubit();
    tabManager.registerTabCubit(tabId, imageListCubit);
    await imageListCubit.onFolderPicked(folder.path);

    final http.Response res = await postCaption(<String, dynamic>{
      'folder': folder.path,
      'filename': 'one.png',
      'text': 'live caption',
    });

    expect(res.statusCode, 200);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['mode'], 'live');

    final AppImage updated = imageListCubit.state.images.firstWhere(
      (AppImage image) => p.basename(image.image.path) == 'one.png',
    );
    expect(updated.captions['default']?.text, 'live caption');
    expect(updated.captions['default']?.model, 'agent');

    final Map<String, dynamic> db =
        jsonDecode(await File(p.join(folder.path, 'db.json')).readAsString())
            as Map<String, dynamic>;
    final Map<String, dynamic> stored = (db['images'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect(
      ((stored['captions'] as Map<String, dynamic>)['default']
              as Map<String, dynamic>)['text'],
      'live caption',
    );
  });

  test('folder refresh picks up newly added images for an open tab', () async {
    final Directory folder = await makeImageFolder('refresh', <String>['r.png']);
    final TabManagerCubit tabManager = TabManagerCubit();
    locator.registerSingleton<TabManagerCubit>(tabManager);
    tabManager.addTab(folder.path);
    final String tabId = tabManager.state.tabs.last.id;
    final ImageListCubit imageListCubit = ImageListCubit();
    tabManager.registerTabCubit(tabId, imageListCubit);
    await imageListCubit.onFolderPicked(folder.path);
    expect(imageListCubit.state.images, hasLength(1));

    await File(p.join(folder.path, 'r2.png')).writeAsBytes(tinyPngBytes);
    final http.Response res = await client.post(
      uri('/api/folders/refresh'),
      headers: authHeader()..['content-type'] = 'application/json',
      body: jsonEncode(<String, dynamic>{'folder': folder.path}),
    );

    expect(res.statusCode, 200);
    expect(
      (jsonDecode(res.body) as Map<String, dynamic>)['refreshed'],
      isTrue,
    );
    expect(imageListCubit.state.images, hasLength(2));
  });

  test('folder refresh for an unopened folder reports refreshed false',
      () async {
    final http.Response res = await client.post(
      uri('/api/folders/refresh'),
      headers: authHeader()..['content-type'] = 'application/json',
      body: jsonEncode(<String, dynamic>{
        'folder': p.join(tempDir.path, 'not_open'),
      }),
    );

    expect(res.statusCode, 200);
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    expect(body['ok'], isTrue);
    expect(body['refreshed'], isFalse);
  });
}
