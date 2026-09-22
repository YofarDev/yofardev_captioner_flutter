import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config/service_locator.dart';
import 'core/constants/app_colors.dart';
import 'core/presentation/pages/home_page.dart';
import 'core/services/route_observer.dart';
import 'features/llm_config/logic/llm_configs_cubit.dart';
import 'features/tab_manager/logic/tab_manager_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator();

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<LlmConfigsCubit>(
          create: (BuildContext context) => LlmConfigsCubit()..onInit(),
        ),
        BlocProvider<TabManagerCubit>(
          create: (BuildContext context) => TabManagerCubit(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: <NavigatorObserver>[routeObserver],
        theme: _buildTheme(),
        home: const HomePage(),
      ),
    );
  }
}

ThemeData _buildTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: lightPink,
    brightness: Brightness.dark,
  ).copyWith(
    surface: shellBackground,
    onSurface: textPrimary,
    primary: accentPink,
    onPrimary: Colors.black,
    secondary: accentPink,
    onSecondary: Colors.black,
    error: destructive,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: shellBackground,
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,
    dividerColor: hairline,
    iconTheme: const IconThemeData(color: textSecondary, size: 18),
    textTheme: const TextTheme(
      bodySmall: TextStyle(color: textSecondary),
      bodyMedium: TextStyle(color: textPrimary),
      bodyLarge: TextStyle(color: textPrimary),
      labelLarge: TextStyle(color: textPrimary),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: accentPink,
      selectionColor: pinkDim,
      selectionHandleColor: accentPink,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panelRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: textMuted),
      filled: true,
      fillColor: panelDark,
      border: _inputBorder(hairline),
      enabledBorder: _inputBorder(hairline),
      focusedBorder: _inputBorder(accentPink),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: panelRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        side: const BorderSide(color: hairline),
      ),
      textStyle: const TextStyle(color: textPrimary, fontFamily: 'Inter'),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll<Color>(panelRaised),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            side: const BorderSide(color: hairline),
          ),
        ),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: panelDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hairline),
      ),
      textStyle: const TextStyle(color: textSecondary, fontSize: 11),
      waitDuration: const Duration(milliseconds: 500),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll<Color>(Color(0x33FFFFFF)),
      trackColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      radius: Radius.circular(3),
      thickness: WidgetStatePropertyAll<double>(6),
      mainAxisMargin: 4,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: lightGrey,
        foregroundColor: textPrimary,
        disabledBackgroundColor: panelRaised,
        disabledForegroundColor: textMuted,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? accentPink : textMuted,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.selected) ? accentPink : textMuted,
      ),
      side: const BorderSide(color: textMuted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? accentPink
            : textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? pinkSurface
            : panelRaised,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelRaised,
      contentTextStyle: const TextStyle(color: textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        side: const BorderSide(color: hairline),
      ),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(radiusSm),
  borderSide: BorderSide(color: color),
);
