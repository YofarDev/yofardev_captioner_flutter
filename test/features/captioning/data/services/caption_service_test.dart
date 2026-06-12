import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/captioning/data/services/caption_service.dart';
import 'package:yofardev_captioner/features/captioning/data/services/image_resizer.dart';
import 'package:yofardev_captioner/features/captioning/data/services/process_runner.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_config.dart';
import 'package:yofardev_captioner/features/llm_config/data/models/llm_provider_type.dart';

import 'caption_service_test.mocks.dart';

@GenerateMocks(<Type>[ProcessRunner, http.Client, ImageResizer])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton(() => Logger('App'));
  });

  group('CaptionService', () {
    late CaptionService service;
    late MockProcessRunner mockProcessRunner;
    late MockClient mockHttpClient;
    late MockImageResizer mockImageResizer;
    late File testImageFile;

    setUp(() async {
      mockProcessRunner = MockProcessRunner();
      mockHttpClient = MockClient();
      mockImageResizer = MockImageResizer();

      // Create a real temp file so readAsBytes works for remote tests
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'caption_test_',
      );
      testImageFile = File('${tempDir.path}/test_image.jpg');
      // Minimal valid JPEG bytes
      await testImageFile.writeAsBytes(<int>[
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0xFF,
        0xD9,
      ]);

      // By default, resize returns the temp file (same path = no cleanup)
      when(
        mockImageResizer.resizeImageIfNecessary(any),
      ).thenAnswer((_) async => testImageFile);

      service = CaptionService(
        processRunner: mockProcessRunner,
        httpClient: mockHttpClient,
        imageResizer: mockImageResizer,
      );
    });

    tearDown(() async {
      if (await testImageFile.parent.exists()) {
        await testImageFile.parent.delete(recursive: true);
      }
    });

    // ─── buildUrl tests ────────────────────────────────────────────

    group('buildUrl', () {
      test('returns unchanged when already ends with chat/completions', () {
        expect(
          service.buildUrl('https://api.openai.com/v1/chat/completions'),
          'https://api.openai.com/v1/chat/completions',
        );
      });

      test('appends chat/completions when URL ends with slash', () {
        expect(
          service.buildUrl('https://api.openai.com/v1/'),
          'https://api.openai.com/v1/chat/completions',
        );
      });

      test('appends /chat/completions when URL has no trailing slash', () {
        expect(
          service.buildUrl('https://api.openai.com/v1'),
          'https://api.openai.com/v1/chat/completions',
        );
      });
    });

    // ─── getCaption routing ────────────────────────────────────────

    group('getCaption routing', () {
      test('routes to local MLX when providerType is localMlx', () async {
        when(mockProcessRunner.run(any, any)).thenAnswer((_) async {
          return ProcessResult(
            0,
            0,
            '<|im_start|>assistant\n\na caption\n==========',
            '',
          );
        });

        final LlmConfig localConfig = LlmConfig(
          name: 'mlx',
          model: 'test-model',
          providerType: LlmProviderType.localMlx,
        );

        final String result = await service.getCaption(
          localConfig,
          File('/test/image.jpg'),
          'describe',
        );

        expect(result, 'a caption');
        verify(mockProcessRunner.run(any, any)).called(1);
        verifyNever(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        );
      });

      test('routes to remote when providerType is remote', () async {
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'choices': <Map<String, dynamic>>[
                <String, dynamic>{
                  'message': <String, dynamic>{'content': 'remote caption'},
                },
              ],
            }),
            200,
          ),
        );

        final LlmConfig remoteConfig = LlmConfig(
          name: 'openai',
          model: 'gpt-4',
          apiKey: 'key',
          url: 'https://api.openai.com/v1',
          providerType: LlmProviderType.remote,
        );

        final String result = await service.getCaption(
          remoteConfig,
          File('/test/image.jpg'),
          'describe',
        );

        expect(result, 'remote caption');
        verify(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).called(1);
        verifyNever(mockProcessRunner.run(any, any));
      });
    });

    // ─── Local caption tests ───────────────────────────────────────

    group('local MLX caption', () {
      test('parses caption from successful MLX output', () async {
        when(mockProcessRunner.run(any, any)).thenAnswer((_) async {
          return ProcessResult(
            0,
            0,
            '<|im_start|>assistant\n\nA beautiful sunset\n==========',
            '',
          );
        });

        final LlmConfig config = LlmConfig(
          name: 'mlx',
          model: 'test',
          providerType: LlmProviderType.localMlx,
        );

        final String result = await service.getCaption(
          config,
          File('/test/img.jpg'),
          'prompt',
        );

        expect(result, 'A beautiful sunset');
      });

      test('throws ApiException when MLX output does not match regex', () {
        when(mockProcessRunner.run(any, any)).thenAnswer((_) async {
          return ProcessResult(0, 0, 'unparsable output', '');
        });

        final LlmConfig config = LlmConfig(
          name: 'mlx',
          model: 'test',
          providerType: LlmProviderType.localMlx,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(isA<ApiException>()),
        );
      });

      test('throws ApiException when MLX exits with non-zero code', () {
        when(mockProcessRunner.run(any, any)).thenAnswer((_) async {
          return ProcessResult(0, 1, '', 'error details');
        });

        final LlmConfig config = LlmConfig(
          name: 'mlx',
          model: 'test',
          providerType: LlmProviderType.localMlx,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.message,
              'message',
              contains('exit code 1'),
            ),
          ),
        );
      });

      test('wraps ProcessException in ApiException', () {
        when(
          mockProcessRunner.run(any, any),
        ).thenThrow(const ProcessException('mlx_vlm.generate', <String>[]));

        final LlmConfig config = LlmConfig(
          name: 'mlx',
          model: 'test',
          providerType: LlmProviderType.localMlx,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.message,
              'message',
              contains('mlx_vlm'),
            ),
          ),
        );
      });

      test('uses custom mlxPath when provided', () async {
        when(mockProcessRunner.run(any, any)).thenAnswer((_) async {
          return ProcessResult(
            0,
            0,
            '<|im_start|>assistant\n\ncaption\n==========',
            '',
          );
        });

        final LlmConfig config = LlmConfig(
          name: 'mlx',
          model: 'test',
          providerType: LlmProviderType.localMlx,
          mlxPath: '/custom/mlx_vlm',
        );

        await service.getCaption(config, File('/test/img.jpg'), 'prompt');

        verify(mockProcessRunner.run('/custom/mlx_vlm', any)).called(1);
      });
    });

    // ─── Remote caption tests ──────────────────────────────────────

    group('remote caption', () {
      test('throws ApiException when URL is null', () {
        final LlmConfig config = LlmConfig(
          name: 'test',
          model: 'gpt-4',
          apiKey: 'key',
          providerType: LlmProviderType.remote,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.message,
              'message',
              contains('URL and API Key'),
            ),
          ),
        );
      });

      test('throws ApiException when apiKey is null', () {
        final LlmConfig config = LlmConfig(
          name: 'test',
          model: 'gpt-4',
          url: 'https://api.example.com',
          providerType: LlmProviderType.remote,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.message,
              'message',
              contains('URL and API Key'),
            ),
          ),
        );
      });

      test('throws ApiException on HTTP error status', () {
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('{"error": "bad"}', 500));

        final LlmConfig config = LlmConfig(
          name: 'test',
          model: 'gpt-4',
          apiKey: 'key',
          url: 'https://api.example.com',
          providerType: LlmProviderType.remote,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.message,
              'message',
              contains('500'),
            ),
          ),
        );
      });

      test('throws ApiException when response has empty choices', () {
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{'choices': <dynamic>[]}),
            200,
          ),
        );

        final LlmConfig config = LlmConfig(
          name: 'test',
          model: 'gpt-4',
          apiKey: 'key',
          url: 'https://api.example.com',
          providerType: LlmProviderType.remote,
        );

        expect(
          () => service.getCaption(config, File('/test/img.jpg'), 'prompt'),
          throwsA(
            isA<ApiException>().having(
              (ApiException e) => e.message,
              'message',
              contains('Invalid response format'),
            ),
          ),
        );
      });
    });

    // ─── ApiException ──────────────────────────────────────────────

    group('ApiException', () {
      test('toString returns formatted message', () {
        final ApiException exception = ApiException('test error');
        expect(exception.toString(), 'ApiException: test error');
      });

      test('message is accessible', () {
        final ApiException exception = ApiException('test error');
        expect(exception.message, 'test error');
      });
    });
  });
}
