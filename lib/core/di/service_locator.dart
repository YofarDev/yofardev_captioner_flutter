import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import '../../features/agent_api/data/services/agent_api_service.dart';
import '../../features/captioning/captioning.dart';
import '../../features/captioning/data/repositories/caption_repository.dart';
import '../../features/captioning/data/repositories/captioning_repository.dart';
import '../../features/captioning/data/services/caption_service.dart';
import '../../features/image_list/data/repositories/app_file_utils.dart';
import '../../features/llm_config/data/repositories/llm_config_service.dart';
import '../../features/llm_config/domain/repositories/llm_config_repository.dart';
import '../../features/tab_manager/domain/services/tab_session_registry.dart';
import '../services/cache_service.dart';

final GetIt locator = GetIt.instance;

/// Single authoritative wiring layer. Every GetIt registration lives here;
/// the architecture checker enforces it.
///
/// Also performs the bootstrap side effect of starting the Agent API when
/// enabled. Root cubits are NOT registered here — they are constructed in
/// `AppState.initState` and provided to the tree (presentation owns
/// presentation).
Future<void> setupServiceLocator() async {
  // Services
  locator.registerLazySingleton<CacheService>(() => const CacheService());
  locator.registerLazySingleton<LlmConfigService>(() => LlmConfigService());
  locator.registerLazySingleton<ILlmConfigRepository>(
    () => locator<LlmConfigService>(),
  );
  locator.registerLazySingleton<CaptionService>(() => CaptionService());
  locator.registerLazySingleton<CaptionRepository>(() => CaptionRepository());
  locator.registerLazySingleton<ICaptioningRepository>(
    () => CaptioningRepository(),
  );
  locator.registerLazySingleton<AppFileUtils>(
    () => AppFileUtils(cacheService: locator<CacheService>()),
  );
  // Shared by TabManagerCubit (writes sessions + tab snapshot) and
  // AgentApiService (reads them) so no data service needs a cubit.
  locator.registerLazySingleton<TabSessionRegistry>(() => TabSessionRegistry());
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

  if (await locator<CacheService>().loadAgentApiEnabled()) {
    await locator<AgentApiService>().start();
  }
}
