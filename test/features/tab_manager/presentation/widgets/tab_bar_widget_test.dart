import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yofardev_captioner/features/tab_manager/domain/models/app_tab.dart';
import 'package:yofardev_captioner/features/tab_manager/domain/services/tab_session_registry.dart';
import 'package:yofardev_captioner/features/tab_manager/presentation/bloc/tab_manager_cubit.dart';
import 'package:yofardev_captioner/features/tab_manager/presentation/widgets/tab_bar_widget.dart';

/// Widget test for the tab bar: add, activate, and close tabs, asserting the
/// TabManagerCubit state transitions AND that closing a tab disposes its
/// session in the shared [TabSessionRegistry].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // TabManagerCubit sets the window title on every state change.
  const MethodChannel windowManagerChannel = MethodChannel('window_manager');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        windowManagerChannel,
        (MethodCall methodCall) async => null,
      );

  Future<(TabManagerCubit, TabSessionRegistry)> pumpBar(
    WidgetTester tester,
  ) async {
    final TabSessionRegistry registry = TabSessionRegistry();
    final TabManagerCubit cubit = TabManagerCubit(sessionRegistry: registry);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<TabManagerCubit>.value(
        value: cubit,
        child: const MaterialApp(home: Scaffold(body: TabBarWidget())),
      ),
    );
    await tester.pump();
    return (cubit, registry);
  }

  testWidgets('renders the default tab and no close button for a single tab', (
    WidgetTester tester,
  ) async {
    final (TabManagerCubit cubit, _) = await pumpBar(tester);

    expect(find.text('New Tab'), findsOneWidget);
    expect(find.text('folder_x'), findsNothing);
    // Single tab cannot be closed.
    expect(find.byIcon(Icons.close), findsNothing);
    expect(cubit.state.tabs.length, 1);
  });

  testWidgets('add button creates a second tab and makes it active', (
    WidgetTester tester,
  ) async {
    final (TabManagerCubit cubit, _) = await pumpBar(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(cubit.state.tabs.length, 2);
    expect(cubit.state.activeTabIndex, 1);
    expect(cubit.state.activeTab.displayName, 'New Tab');
    // Two tabs → every tab shows a close button (one per tab, plus the add
    // button's icon is different).
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('tapping a tab switches the active tab', (
    WidgetTester tester,
  ) async {
    final (TabManagerCubit cubit, _) = await pumpBar(tester);
    cubit.addTab('/tmp/folder_x');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(cubit.state.activeTabIndex, 1);
    expect(find.text('folder_x'), findsOneWidget);

    await tester.tap(find.text('New Tab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(cubit.state.activeTabIndex, 0);
    expect(cubit.state.activeTab.displayName, 'New Tab');
  });

  testWidgets('closing a tab removes it and disposes its session', (
    WidgetTester tester,
  ) async {
    final (TabManagerCubit cubit, TabSessionRegistry registry) = await pumpBar(
      tester,
    );
    cubit.addTab('/tmp/folder_x');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Touch the session so the registry owns one for the folder tab.
    final String folderTabId = cubit.state.tabs
        .where((AppTab tab) => tab.folderPath == '/tmp/folder_x')
        .single
        .id;
    expect(registry.peek(folderTabId), isNotNull);

    // Close the folder tab via its close icon (second tab's close button).
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(cubit.state.tabs.length, 1);
    expect(cubit.state.activeTab.displayName, 'New Tab');
    expect(find.text('folder_x'), findsNothing);
    // Closing the tab must dispose its session.
    expect(registry.peek(folderTabId), isNull);
  });
}
