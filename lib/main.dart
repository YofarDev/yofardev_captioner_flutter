import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wires every dependency and starts the Agent API when enabled (all inside
  // setupServiceLocator).
  await setupServiceLocator();

  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final double displayHeight = primaryDisplay.size.height * 0.85;
    final double displayWidth = primaryDisplay.size.width * 0.7;
    final WindowOptions windowOptions = WindowOptions(
      title: 'Yofardev Captioner',
      size: Size(displayWidth, displayHeight),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const App());
}
