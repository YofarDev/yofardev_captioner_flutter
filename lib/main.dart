import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'features/captioning/logic/captioning_cubit.dart';
import 'features/image_operations/logic/image_operations_cubit.dart';
import 'features/image_list/logic/image_list_cubit.dart';
import 'features/llm_config/logic/llm_configs_cubit.dart';
import 'core/constants/app_colors.dart';
import 'screens/home_page.dart';
import 'core/config/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();
  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final double displayHeight = primaryDisplay.size.height * 0.8;
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<ImageListCubit>(
          create: (BuildContext context) => ImageListCubit()..onInit(),
        ),
        BlocProvider<CaptioningCubit>(
          create: (BuildContext context) =>
              CaptioningCubit(context.read<ImageListCubit>()),
        ),
        BlocProvider<ImageOperationsCubit>(
          create: (BuildContext context) =>
              ImageOperationsCubit(context.read<ImageListCubit>()),
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
            bodySmall: TextStyle(color: Colors.white, fontFamily: 'Inter'),
            bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Inter'),
            bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Inter'),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}
