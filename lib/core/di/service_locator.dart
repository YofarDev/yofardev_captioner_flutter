import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../../features/agent_api/data/services/agent_api_service.dart';
import '../../features/captioning/data/repositories/caption_repository.dart';
import '../../features/captioning/data/repositories/captioning_repository.dart';
import '../../features/captioning/data/services/caption_service.dart';
import '../../features/image_list/data/repositories/app_file_utils.dart';
import '../../features/image_list/data/services/filter_parser_engine.dart';
import '../../features/llm_config/data/repositories/llm_config_service.dart';
import '../../features/llm_config/logic/llm_configs_cubit.dart';
import '../../features/tab_manager/logic/tab_manager_cubit.dart';
import '../services/cache_service.dart';

final GetIt locator = GetIt.instance;

/// Single authoritative wiring layer. Every GetIt registration lives here;
/// the architecture checker enforces it.
///
/// Also performs the bootstrap side effects that used to live in main.dart:
/// creating the two root cubits (temporary bridge for AgentApiService, see
/// the ratchet marker below) and starting the Agent API when enabled.
Future<void> setupServiceLocator() async {
  // Services
  locator.registerLazySingleton<CacheService>(() => const CacheService());
  locator.registerLazySingleton<LlmConfigService>(() => LlmConfigService());
  locator.registerLazySingleton<CaptionService>(() => CaptionService());
  locator.registerLazySingleton<CaptionRepository>(() => CaptionRepository());
  locator.registerLazySingleton<CaptioningRepository>(
    () => CaptioningRepository(),
  );
  locator.registerLazySingleton<AppFileUtils>(
    () => AppFileUtils(cacheService: locator<CacheService>()),
  );
  locator.registerLazySingleton<AgentApiService>(
    () => AgentApiService(
      cacheService: locator<CacheService>(),
      llmConfigService: locator<LlmConfigService>(),
    ),
  );

  // Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    // ignore: avoid_print
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  locator.registerLazySingleton<Logger>(() => Logger('App'));

  // Root cubits are created here instead of inside BlocProviders so the
  // AgentApiService can reach their live state through get_it.
  // ratchet: agent-api-cubit-access (temporary bridge, removed in Phase 2)
  locator.registerLazySingleton<LlmConfigsCubit>(
    () =>
        LlmConfigsCubit(llmConfigService: locator<LlmConfigService>())
          ..onInit(),
  );
  // ratchet: agent-api-cubit-access (temporary bridge, removed in Phase 2)
  locator.registerLazySingleton<TabManagerCubit>(
    () => TabManagerCubit(
      cacheService: locator<CacheService>(),
      fileUtils: locator<AppFileUtils>(),
      filterEngine: const FilterParserCaptionEngine(),
    ),
  );

  if (await locator<CacheService>().loadAgentApiEnabled()) {
    await locator<AgentApiService>().start();
  }
}
