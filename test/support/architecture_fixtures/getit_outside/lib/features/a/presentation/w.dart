import '../../../core/di/service_locator.dart';

class W {
  void boot() {
    locator<Service>();
  }

  void bad() {
    registerSingleton(Service());
  }
}

void registerSingleton(Object instance) {}
