import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import '../../features/captioning/data/repositories/caption_repository.dart';
import '../../features/captioning/data/repositories/captioning_repository.dart';
import '../../features/captioning/data/services/caption_service.dart';
import '../../services/llm_config_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Services
  locator.registerLazySingleton(() => CaptionService());
  locator.registerLazySingleton(() => LlmConfigService());
  locator.registerLazySingleton(() => CaptionRepository());
  locator.registerLazySingleton(() => CaptioningRepository());

  // Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    // ignore: avoid_print
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  locator.registerLazySingleton(() => Logger('App'));
}
