import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yofardev_captioner/core/config/service_locator.dart';
import 'package:yofardev_captioner/features/captioning/data/services/process_runner.dart';
import 'package:yofardev_captioner/features/structured_captioning/data/services/sam_process_service.dart';

import 'sam_process_service_test.mocks.dart';

@GenerateMocks(<Type>[ProcessRunner])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton(() => Logger('TestSam'));
  });

  tearDown(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SamProcessService.cachedPythonPath = null;
  });

  group('SamProcessService', () {
    late SamProcessService service;
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
      service = SamProcessService(processRunner: mockRunner);
      // Skip asset extraction in all tests.
      // ignore: invalid_use_of_visible_for_testing_member
      service.scriptPathOverride = '/fake/sam3_wrapper.py';
    });

    group('findSamPythonForTest', () {
      test('probes candidates and picks first one with SAM3', () async {
        when(
          mockRunner.run('python3.11', <String>[
            '-c',
            'from mlx_vlm.models.sam3.generate import Sam3Predictor',
          ]),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        final String python = await service.findSamPythonForTest();
        expect(python, 'python3.11');
      });

      test('skips failing interpreters and picks next working one', () async {
        when(
          mockRunner.run('python3.11', any),
        ).thenThrow(const ProcessException('python3.11', <String>[]));

        when(
          mockRunner.run('python3.12', <String>[
            '-c',
            'from mlx_vlm.models.sam3.generate import Sam3Predictor',
          ]),
        ).thenAnswer((_) async => ProcessResult(1, 1, '', 'ImportError'));

        when(
          mockRunner.run('python3.13', <String>[
            '-c',
            'from mlx_vlm.models.sam3.generate import Sam3Predictor',
          ]),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        final String python = await service.findSamPythonForTest();
        expect(python, 'python3.13');
      });

      test('falls back to python3 when nothing works', () async {
        when(
          mockRunner.run(any, any),
        ).thenAnswer((_) async => ProcessResult(1, 1, '', 'nope'));

        final String python = await service.findSamPythonForTest();
        expect(python, 'python3');
      });

      test('caches result on subsequent calls', () async {
        when(
          mockRunner.run('python3.11', any),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        await service.findSamPythonForTest();
        await service.findSamPythonForTest();

        verify(
          mockRunner.run('python3.11', <String>[
            '-c',
            'from mlx_vlm.models.sam3.generate import Sam3Predictor',
          ]),
        ).called(1);
      });
    });

    group('detectObjects', () {
      test('returns parsed detections on success', () async {
        // ignore: invalid_use_of_visible_for_testing_member
        SamProcessService.cachedPythonPath = 'python3.11';

        const String imagePath = '/tmp/img.jpg';
        const List<String> objectNames = <String>['cat', 'dog'];

        final List<Map<String, dynamic>> samOutput = <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'cat',
            'bbox': <int>[100, 200, 300, 400],
          },
          <String, dynamic>{'name': 'dog', 'bbox': null},
        ];

        when(
          mockRunner.run(
            'python3.11',
            argThat(
              containsAll(<String>[
                '--image',
                imagePath,
                '--objects',
                jsonEncode(objectNames),
              ]),
            ),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, 0, jsonEncode(samOutput), ''),
        );

        final List<SamDetection> results = await service.detectObjects(
          imagePath,
          objectNames,
        );

        expect(results, hasLength(2));
        expect(results[0].name, 'cat');
        expect(results[0].bbox, <int>[100, 200, 300, 400]);
        expect(results[1].name, 'dog');
        expect(results[1].bbox, isNull);
      });

      test('returns empty list on non-zero exit code', () async {
        // ignore: invalid_use_of_visible_for_testing_member
        SamProcessService.cachedPythonPath = 'python3.11';

        when(mockRunner.run('python3.11', any)).thenAnswer(
          (_) async => ProcessResult(1, 1, '', 'ModuleNotFoundError'),
        );

        final List<SamDetection> results = await service.detectObjects(
          '/tmp/img.jpg',
          <String>['cat'],
        );

        expect(results, isEmpty);
      });

      test('returns empty list on empty stdout', () async {
        // ignore: invalid_use_of_visible_for_testing_member
        SamProcessService.cachedPythonPath = 'python3.11';

        when(
          mockRunner.run('python3.11', any),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        final List<SamDetection> results = await service.detectObjects(
          '/tmp/img.jpg',
          <String>['cat'],
        );

        expect(results, isEmpty);
      });

      test('returns empty list on exception', () async {
        // ignore: invalid_use_of_visible_for_testing_member
        SamProcessService.cachedPythonPath = 'python3.11';

        when(
          mockRunner.run('python3.11', any),
        ).thenThrow(const ProcessException('python3.11', <String>[]));

        final List<SamDetection> results = await service.detectObjects(
          '/tmp/img.jpg',
          <String>['cat'],
        );

        expect(results, isEmpty);
      });

      test('handles partial detections (some null bboxes)', () async {
        // ignore: invalid_use_of_visible_for_testing_member
        SamProcessService.cachedPythonPath = 'python3.11';

        const String imagePath = '/tmp/img.jpg';
        const List<String> objectNames = <String>['tree', 'car', 'person'];

        final List<Map<String, dynamic>> samOutput = <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'tree',
            'bbox': <int>[50, 50, 150, 150],
          },
          <String, dynamic>{'name': 'car', 'bbox': null},
          <String, dynamic>{
            'name': 'person',
            'bbox': <int>[400, 100, 600, 300],
          },
        ];

        when(
          mockRunner.run(
            'python3.11',
            argThat(
              containsAll(<String>[
                '--image',
                imagePath,
                '--objects',
                jsonEncode(objectNames),
              ]),
            ),
          ),
        ).thenAnswer(
          (_) async => ProcessResult(0, 0, jsonEncode(samOutput), ''),
        );

        final List<SamDetection> results = await service.detectObjects(
          imagePath,
          objectNames,
        );

        expect(results, hasLength(3));
        expect(results[0].bbox, isNotNull);
        expect(results[1].bbox, isNull);
        expect(results[2].bbox, isNotNull);
      });
    });
  });
}
