import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'logic/images/images_cubit.dart';
import 'logic/llm_config/llm_configs_cubit.dart';
import 'res/app_colors.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final double displayHeight = primaryDisplay.size.height * 0.8;
    final double displayWidth = primaryDisplay.size.width * 0.6;
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<ImagesCubit>(
          create: (BuildContext context) => ImagesCubit()..onInit(),
        ),
        BlocProvider<LlmConfigsCubit>(
          create: (BuildContext context) => LlmConfigsCubit()..onInit(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: lightPink,
            brightness: Brightness.dark,
          ).copyWith(onSurface: Colors.white),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}
