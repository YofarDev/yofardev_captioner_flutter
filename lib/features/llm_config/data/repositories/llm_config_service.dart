import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/models/llm_configs.dart';
import '../../domain/repositories/llm_config_repository.dart';

/// SharedPreferences-backed implementation of [ILlmConfigRepository].
class LlmConfigService implements ILlmConfigRepository {
  static const String _llmConfigsKey = 'llm_configs';

  @override
  Future<Either<Failure, void>> saveLlmConfigs(LlmConfigs configs) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(configs.toJson());
      await prefs.setString(_llmConfigsKey, jsonString);
      return const Right<Failure, void>(null);
    } on FormatException catch (e, st) {
      return Left<Failure, void>(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LlmConfigService.save'),
      );
    } on FileSystemException catch (e, st) {
      return Left<Failure, void>(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LlmConfigService.save'),
      );
    } catch (e, st) {
      return Left<Failure, void>(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LlmConfigService.save'),
      );
    }
  }

  @override
  Future<Either<Failure, LlmConfigs?>> loadLlmConfigs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_llmConfigsKey);
      if (jsonString != null) {
        return Right<Failure, LlmConfigs?>(
          LlmConfigs.fromJson(jsonDecode(jsonString) as Map<String, dynamic>),
        );
      }
      return const Right<Failure, LlmConfigs?>(null);
    } on FormatException catch (e, st) {
      return Left<Failure, LlmConfigs?>(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LlmConfigService.load'),
      );
    } on FileSystemException catch (e, st) {
      return Left<Failure, LlmConfigs?>(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LlmConfigService.load'),
      );
    } catch (e, st) {
      return Left<Failure, LlmConfigs?>(
        mapExceptionToFailure(e, stackTrace: st, tag: 'LlmConfigService.load'),
      );
    }
  }
}
