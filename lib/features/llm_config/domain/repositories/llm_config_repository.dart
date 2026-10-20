import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/models/llm_configs.dart';

/// Contract for persisting and loading the user's LLM configurations.
///
/// Never throws across the boundary: failures are returned as typed
/// [Failure] values on the `Left` of the [Either].
abstract class ILlmConfigRepository {
  /// Saves [configs], replacing any previously persisted configuration set.
  Future<Either<Failure, void>> saveLlmConfigs(LlmConfigs configs);

  /// Loads the persisted configurations, or `Right(null)` when none were
  /// saved yet.
  Future<Either<Failure, LlmConfigs?>> loadLlmConfigs();
}
